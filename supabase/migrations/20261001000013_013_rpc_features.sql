-- db/migrations/20261007_013_rpc_features.sql
-- Sprint 1: feature RPCs — submit_triage, advocate_search, request_update,
-- next_invoice_no.
-- Sources: TRD section 5.7 signatures + database_schema section 4 (RPC table).
-- Ruling q: TRD section 6.3 F7 references create_invoice but schema section 4
-- omits it — authored in part 2 of this file: inserts invoice + items,
-- recomputes subtotal/vat/total (ruling e structural checks enforce them),
-- assigns next_invoice_no. Voided rows keep their numbers (never reused).
-- All functions: security definer, set search_path = public.

-- Records the triage session, materialises checklist_items from templates
-- plus AI suggestions, enforces the 10-per-24h rate limit.
create or replace function submit_triage(p_input jsonb)
returns ai_triage_sessions
language plpgsql security definer set search_path = public as $$
declare
  v_row       ai_triage_sessions;
  v_case_id   uuid;
  v_case_type text;
  v_n         int;
begin
  select count(*) into v_n from ai_triage_sessions
   where user_id = auth.uid() and created_at > now() - interval '24 hours';
  if v_n >= 10 then
    raise exception 'rate_limited';
  end if;

  v_case_type := coalesce(p_input ->> 'case_type', 'criminal');
  v_case_id   := nullif(p_input ->> 'case_id', '')::uuid;

  -- Idempotent under client retry: the triage_case_unique partial index is the
  -- backstop; return the existing session instead of double-instantiating.
  if v_case_id is not null then
    select * into v_row from ai_triage_sessions where case_id = v_case_id;
    if found then
      return v_row;
    end if;
  end if;

  insert into ai_triage_sessions (
    user_id, case_id, input_hash, input_redacted, output_json,
    model, prompt_version, tokens_used, fallback_used
  )
  values (
    auth.uid(), v_case_id,
    encode(digest(coalesce(p_input ->> 'raw', '{}'), 'sha256'), 'hex'),
    coalesce(p_input ->> 'redacted', '{}'),
    coalesce(p_input -> 'output', '{}'::jsonb),
    p_input ->> 'model', p_input ->> 'prompt_version',
    coalesce((p_input ->> 'tokens_used')::int, 0),
    coalesce((p_input ->> 'fallback_used')::boolean, false)
  )
  returning * into v_row;

  if v_case_id is not null then
    insert into checklist_items (case_id, template_id, item_name_bn, importance, status, ai_reason_bn)
    select v_case_id, t.id, t.item_name_bn, t.importance, 'suggested_pending_advocate', t.purpose_bn
      from checklist_templates t
     where t.active and t.case_type = v_case_type;
  end if;

  return v_row;
end $$;

-- Ranked, index-friendly search over the verified advocate projection.
-- No win-rate input exists (ruling: TRD section 5.7).
create or replace function advocate_search(
  p_type text, p_district text, p_court text, p_max_fee numeric, p_lang text
) returns table (
  profile_id      uuid,
  full_name       text,
  specializations text[],
  courts          text[],
  districts       text[],
  languages       text[],
  years_practice  int,
  fee_min_bdt     numeric,
  fee_max_bdt     numeric
)
language sql stable security definer set search_path = public as $$
  select a.profile_id, p.full_name, a.specializations, a.courts, a.districts,
         a.languages, a.years_practice, a.fee_min_bdt, a.fee_max_bdt
    from advocates a join profiles p on p.id = a.profile_id
   where a.verification = 'verified'
     and (p_type     is null or p_type     = any (a.specializations))
     and (p_district is null or p_district = any (a.districts))
     and (p_court    is null or p_court    = any (a.courts))
     and (p_max_fee  is null or a.fee_min_bdt is null or a.fee_min_bdt <= p_max_fee)
     and (p_lang     is null or p_lang     = any (a.languages))
   order by a.years_practice desc nulls last, a.fee_min_bdt asc nulls last
   limit 20;
$$;

-- Client asks the advocate to update the case; deduped to once per 24h.
create or replace function request_update(p_case_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare v_adv uuid;
begin
  select c.advocate_id into v_adv from cases c
   where c.id = p_case_id and c.client_id = auth.uid();
  if not found then
    raise exception 'not_case_client';
  end if;
  if v_adv is null then
    raise exception 'case_unassigned';
  end if;

  insert into notifications(user_id, kind, title_bn, body_bn, payload, dedupe_key)
  values (v_adv, 'case.update_requested',
          'ক্লায়েন্ট আপডেট চেয়েছেন',
          'আপনার একটি মামলায় ক্লায়েন্ট সর্বশেষ অবস্থা জানতে চেয়েছেন।',
          jsonb_build_object('case_id', p_case_id),
          'case.update_requested:' || p_case_id::text || ':' || date_trunc('day', now())::date)
  on conflict (dedupe_key) do nothing;

  if not found then
    raise exception 'update_request_duplicate';
  end if;
end $$;

-- Per-advocate yearly invoice sequence: INV-{YEAR}-{SEQ}, never reused.
-- The invoices.invoice_no UNIQUE constraint is the race backstop: on
-- conflict the caller retries and reads the next sequence value.
create or replace function next_invoice_no(p_advocate uuid)
returns text
language plpgsql security definer set search_path = public as $$
declare
  v_year int := extract(year from now())::int;
  v_seq  int;
begin
  select coalesce(max(
    nullif(regexp_replace(invoice_no, '^INV-[0-9]{4}-', ''), '')::int
  ), 0) + 1 into v_seq
  from invoices
  where advocate_id = p_advocate
    and invoice_no like 'INV-' || v_year::text || '-%';

  return 'INV-' || v_year::text || '-' || lpad(v_seq::text, 4, '0');
end $$;

-- Ruling q: creates the invoice and its line items atomically, recomputes
-- subtotal/vat/total from the items (the ruling-e checks enforce them), and
-- assigns next_invoice_no. Voided rows keep their numbers (never reused).
create or replace function create_invoice(
  p_case_id uuid, p_items jsonb, p_due_date date
) returns invoices
language plpgsql security definer set search_path = public as $$
declare
  v_case    cases;
  v_inv     invoices;
  v_no      text;
  v_sub     numeric(12,2);
  v_rate    numeric(5,2) := 15.00;
  v_vat     numeric(12,2);
  v_total   numeric(12,2);
begin
  select * into v_case from cases where id = p_case_id;
  if not found then
    raise exception 'case_not_found';
  end if;
  if v_case.advocate_id is distinct from auth.uid() and not is_admin() then
    raise exception 'not_case_advocate';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'invoice_items_required';
  end if;

  select coalesce(sum((x ->> 'amount_bdt')::numeric(12,2)), 0)
    into v_sub
    from jsonb_array_elements(p_items) as x;
  v_vat   := round(v_sub * v_rate / 100, 2);
  v_total := round(v_sub + v_vat, 2);

  -- Retry loop around the unique race on invoice_no (see next_invoice_no).
  for i in 1..5 loop
    begin
      v_no := next_invoice_no(v_case.advocate_id);

      insert into invoices (
        invoice_no, case_id, advocate_id, client_id,
        subtotal_bdt, vat_rate, vat_bdt, total_bdt, paid_bdt, state, due_date
      )
      values (
        v_no, v_case.id, v_case.advocate_id, v_case.client_id,
        v_sub, v_rate, v_vat, v_total, 0, 'draft', p_due_date
      )
      returning * into v_inv;
      exit;
    exception when unique_violation then
      if i = 5 then
        raise exception 'invoice_no_race_exhausted';
      end if;
    end;
  end loop;

  insert into invoice_items (invoice_id, description, amount_bdt)
  select v_inv.id,
         coalesce(x ->> 'description', ''),
         (x ->> 'amount_bdt')::numeric(12,2)
    from jsonb_array_elements(p_items) as x;

  insert into audit_logs(actor_id, actor_role, action, entity, entity_id)
  values (auth.uid(), 'advocate', 'invoice.create', 'invoices', v_inv.id);

  return v_inv;
end $$;
