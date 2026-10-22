-- db/migrations/20261022000001_accept_sos_rpc.sql
-- Sprint 2 Task 2: harden accept_sos / create_case_from_sos (TRD §5.7,
-- database_schema §4.1). Migration 012 introduced these RPCs; this file:
--
--   1. Makes SOS-born cases case_type = 'bail' (PRD F3 is "Arrest / Bail";
--      the bail checklist templates — FIR copy, arrest memo, arrested-person
--      NID — are the emergency-arrest checklist) and clones the active
--      'bail' templates as suggested_pending_advocate.
--   2. Sets search_path = public, extensions on both SECURITY DEFINER
--      functions (Iron Laws §5 / agent_rules §2).
--   3. Adds ON CONFLICT (dedupe_key) DO NOTHING to the notification
--      fan-out, matching every other notification insert (014/015/018).
--
-- Behaviour otherwise identical to 012: is_verified_advocate() gate, row
-- lock on status='open', NULL on race loss (sos_already_taken), audit row
-- sos.accept, then create_case_from_sos.
--
-- Grants: accept_sos → authenticated; create_case_from_sos stays internal
-- (revoked from public, never granted — it is invoked only through the
-- security-definer accept_sos).

create or replace function create_case_from_sos(p_sos_id uuid)
returns uuid
language plpgsql security definer
set search_path = public, extensions as $$
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
  values (v_sos.client_id, v_sos.advocate_id, v_sos.id, 'bail',
          v_sos.court, v_sos.district, 'active')
  returning id into v_case;

  insert into checklist_items (case_id, template_id, item_name_bn, importance, status, ai_reason_bn)
  select v_case, t.id, t.item_name_bn, t.importance, 'suggested_pending_advocate', t.purpose_bn
    from checklist_templates t
   where t.active and t.case_type = 'bail';

  insert into notifications (user_id, kind, title_bn, body_bn, payload, dedupe_key)
  values (v_sos.client_id, 'sos.accepted',
          'আপনার জরুরি অনুরোধ গৃহীত হয়েছে',
          'একজন যাচাইকৃত উকিল আপনার মামলা গ্রহণ করেছেন।',
          jsonb_build_object('case_id', v_case, 'sos_id', v_sos.id),
          'sos.accepted:' || v_sos.id::text)
  on conflict (dedupe_key) do nothing;

  return v_case;
end $$;

create or replace function accept_sos(p_sos_id uuid)
returns sos_requests
language plpgsql security definer
set search_path = public, extensions as $$
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

revoke execute on function accept_sos(uuid) from public;
revoke execute on function create_case_from_sos(uuid) from public;
grant execute on function accept_sos(uuid) to authenticated;

-- Supabase's ddl_command_end triggers auto-grant execute to anon /
-- authenticated / service_role on every new function. create_case_from_sos is
-- an internal helper invoked only through the security-definer accept_sos, so
-- drop those platform grants too; otherwise any authenticated caller could
-- spawn a case straight from an accepted SOS.
revoke execute on function create_case_from_sos(uuid) from authenticated, anon, service_role;
