-- db/migrations/20261006_012_rpc_core.sql
-- Sprint 1: core RPCs — complete_signup (with the ruling-b role gate),
-- accept_sos (ruling-n signature), create_case_from_sos.
-- Sources: TRD section 5.7 signatures + database_schema section 4.1 body for
-- accept_sos. publish_ai_summary / admin_force_publish / PIN RPCs are OWNED
-- BY 018 (ruling p) and are not defined here.
-- All functions: security definer, set search_path = public.

-- Ruling b: role unconstrained would let any client self-assign 'admin' and
-- then pass is_admin() everywhere (the doc's own sharpest warning). Admin
-- rows are created only by seed or manual SQL.
create or replace function complete_signup(
  p_role user_role, p_full_name text, p_language text
) returns profiles
language plpgsql security definer set search_path = public as $$
declare v_row profiles;
begin
  if p_role not in ('client', 'advocate') then
    raise exception 'signup_role_not_allowed';
  end if;

  insert into profiles (id, role, full_name, phone, language)
  values (
    auth.uid(),
    p_role,
    nullif(btrim(coalesce(p_full_name, '')), ''),
    coalesce(
      (auth.jwt() ->> 'phone'),
      (auth.jwt() -> 'user_metadata' ->> 'phone'),
      ''
    ),
    case when p_language in ('bn', 'en') then p_language else 'bn' end
  )
  on conflict (id) do update
    set full_name = excluded.full_name,
        language  = excluded.language
  returning * into v_row;

  return v_row;
end $$;

-- Ruling n: implement the BODY's signature, not the stale heading —
-- (p_sos_id uuid) returns sos_requests; a caller-supplied p_advocate_id
-- would let advocates accept SOS on someone else's behalf.
create or replace function accept_sos(p_sos_id uuid)
returns sos_requests
language plpgsql security definer set search_path = public as $$
declare v_row sos_requests;
begin
  if not is_verified_advocate() then
    raise exception 'not_verified_advocate';
  end if;

  -- Row lock: exactly one advocate can win (PRD F3 invariant)
  update sos_requests
     set status = 'accepted', advocate_id = auth.uid(), accepted_at = now()
   where id = p_sos_id and status = 'open'
  returning * into v_row;

  if v_row.id is null then
    return null;                      -- lost the race -> client shows "already taken"
  end if;

  insert into audit_logs(actor_id, actor_role, action, entity, entity_id)
  values (auth.uid(), 'advocate', 'sos.accept', 'sos_requests', p_sos_id);

  -- Case creation + checklist instantiation happen in create_case_from_sos()
  perform create_case_from_sos(p_sos_id);
  return v_row;
end $$;

-- Creates the case row from an accepted SOS and clones the admin checklist
-- templates as suggested_pending_advocate instances.
create or replace function create_case_from_sos(p_sos_id uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_sos  sos_requests;
  v_case uuid;
begin
  select * into v_sos from sos_requests where id = p_sos_id;
  if not found then
    raise exception 'sos_not_found';
  end if;
  if v_sos.status <> 'accepted' or v_sos.advocate_id is null then
    raise exception 'sos_not_accepted';
  end if;
  if v_sos.advocate_id is distinct from auth.uid() and not is_admin() then
    raise exception 'not_winning_advocate';
  end if;

  -- Idempotent under double-accept: the cases.sos_id unique constraint is the
  -- backstop; return the existing row instead of raising.
  select id into v_case from cases where sos_id = p_sos_id;
  if found then
    return v_case;
  end if;

  insert into cases (client_id, advocate_id, sos_id, case_type, court, district, state)
  values (v_sos.client_id, v_sos.advocate_id, v_sos.id, 'criminal',
          v_sos.court, v_sos.district, 'active')
  returning id into v_case;

  insert into checklist_items (case_id, template_id, item_name_bn, importance, status, ai_reason_bn)
  select v_case, t.id, t.item_name_bn, t.importance, 'suggested_pending_advocate', t.purpose_bn
    from checklist_templates t
   where t.active and t.case_type = 'criminal';

  insert into notifications(user_id, kind, title_bn, body_bn, payload, dedupe_key)
  values (v_sos.client_id, 'sos.accepted',
          'আপনার জরুরি অনুরোধ গৃহীত হয়েছে',
          'একজন যাচাইকৃত উকিল আপনার মামলা গ্রহণ করেছেন।',
          jsonb_build_object('case_id', v_case, 'sos_id', v_sos.id),
          'sos.accepted:' || v_sos.id::text);

  return v_case;
end $$;
