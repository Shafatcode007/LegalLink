/*
db/migrations/20261001000018_018_rpc_hardening.sql
Full plpgsql bodies for the HITL RPCs - resolves F-4 (caller identity),
restores spec step 6 (notification fan-out), and adds the PIN lifecycle
RPCs required before the F-3 pin_guard (017) can ship.

TRD ERRATA - transaction-rollback semantics (READ BEFORE EDITING)
PostgREST runs each RPC in ONE transaction and rolls back EVERYTHING on
an uncaught exception. A raise exception issued AFTER incrementing
advocates.pin_fail_count would erase the increment, so the lockout could
never fire. Therefore:
  - RAISE happens only BEFORE any counter mutation
  - A WRONG PIN increments the counter and RETURNS NULL instead of raising
TRD 9.3 error-map change: invalid_pin = NULL return, not raise.
*/

-- 015: shared updated_at triggers + execute-grant matrix.

create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- =====================================================================
-- Advocate PIN Security Guard (Test F-3a)
-- =====================================================================
create or replace function advocate_pin_guard() returns trigger
language plpgsql as $$
begin
  if auth.uid() = old.profile_id
     and coalesce(current_setting('app.internal_write', true), '0') <> '1'
     and (
       new.pin_hash is distinct from old.pin_hash
       or new.pin_fail_count < old.pin_fail_count
       or (new.pin_locked_until is null and old.pin_locked_until is not null)
     ) then
    raise exception 'pin_guard: advocates cannot modify their own PIN security columns';
  end if;
  return new;
end;
$$;

-- =====================================================================
-- publish_ai_summary
-- =====================================================================
create or replace function publish_ai_summary(
  p_summary_id uuid,
  p_pin text,
  p_final_bn text
) returns ai_summaries
language plpgsql security definer
set search_path = public, extensions as $$
declare
  v_summary ai_summaries;
  v_advocate advocates;
  v_pin_valid boolean;
begin
  perform set_config('app.internal_write', '1', true);

  select * into v_summary from ai_summaries where id = p_summary_id;
  if not found then
    raise exception 'summary_not_found';
  end if;
  if v_summary.state <> 'draft' then
    raise exception 'not_draft';
  end if;
  if v_summary.expires_at < now() then
    raise exception 'draft_expired';
  end if;
  if p_final_bn is null or btrim(p_final_bn) = '' then
    raise exception 'final_required';
  end if;

  select * into v_advocate from advocates where profile_id = auth.uid();
  if not found then
    raise exception 'not_case_advocate';
  end if;
  if v_advocate.pin_hash is null then
    raise exception 'pin_not_set';
  end if;
  if v_advocate.pin_locked_until is not null
     and v_advocate.pin_locked_until > now() then
    raise exception 'pin_locked';
  end if;

  v_pin_valid := (crypt(p_pin, v_advocate.pin_hash) = v_advocate.pin_hash);

  if not v_pin_valid then
    if v_advocate.pin_fail_count + 1 >= 5 then
      update advocates
         set pin_fail_count = pin_fail_count + 1,
             pin_locked_until = now() + interval '30 minutes'
       where profile_id = auth.uid();
    else
      update advocates
         set pin_fail_count = pin_fail_count + 1
       where profile_id = auth.uid();
    end if;
    return null;
  end if;

  update advocates
     set pin_fail_count = 0,
         pin_locked_until = null
   where profile_id = auth.uid();

  update ai_summaries
     set state = 'published',
         final_bn = coalesce(p_final_bn, draft_bn),
         approved_by = auth.uid(),
         published_by = 'advocate',
         updated_at = now()
   where id = p_summary_id
   returning * into v_summary;

  insert into audit_logs (actor_id, actor_role, action, entity, entity_id, metadata)
  values (auth.uid(), 'advocate', 'summary.publish', 'ai_summaries', p_summary_id, '{}'::jsonb);

  insert into notifications (user_id, kind, title_bn, body_bn, payload, dedupe_key, channel)
  select c.client_id, 'summary.published',
         'নতুন আইনি বিজ্ঞপ্তি প্রকাশিত হয়েছে',
         'আপনার আইনজীবী আপনার মামলার শুনানির একটি সহজ বাংলা সারাংশ প্রকাশ করেছেন।',
         jsonb_build_object('case_id', v_summary.case_id, 'summary_id', p_summary_id),
         'summary:' || p_summary_id, 'push'
    from cases c
   where c.id = v_summary.case_id
   on conflict (dedupe_key) do nothing;

  return v_summary;
end;
$$;

-- =====================================================================
-- annual_reverify_reminder
-- =====================================================================
create or replace function annual_reverify_reminder() returns void
language plpgsql security definer
set search_path = public as $$
begin
  insert into notifications(user_id, kind, title_bn, body_bn, dedupe_key)
  select a.profile_id, 'advocate.reverify_due',
         'বার কাউন্সিল যাচাই নবায়ন করুন',
         'আপনার সনদ বার্ষিক যাচাইয়ের সময় হয়েছে। অনুগ্রহ করে প্রামাণিক দলিল জমা দিন।',
         'reverify:' || a.profile_id || ':' || date_trunc('day', now())::date
  from advocates a
  where a.verification = 'verified'
    and a.reverify_due_at between now() and now() + interval '30 days'
  on conflict (dedupe_key) do nothing;

  update advocates
  set verification = 'pending',
      reverify_due_at = now() + interval '90 days'
  where verification = 'verified'
    and reverify_due_at is not null
    and reverify_due_at <= now();

  insert into audit_logs(actor_id, actor_role, action, entity, metadata)
  select null, 'admin', 'advocate.reverify_swept', 'advocates',
         jsonb_build_object('profile_id', a.profile_id, 'due_at', a.reverify_due_at)
  from advocates a
  where a.verification = 'pending'
    and a.reverify_due_at is not null
    and a.reverify_due_at <= now() - interval '90 days';
end;
$$;

-- Helpers: predicate-only, never callable from the API surface.
revoke execute on function is_admin() from public;
revoke execute on function is_verified_advocate() from public;
revoke execute on function has_case_access(uuid) from public;
revoke execute on function set_updated_at() from public;

-- RPC surface: revoke defaults, then grant the exact client-reachable set.
revoke execute on function complete_signup(user_role, text, text) from public;
revoke execute on function accept_sos(uuid) from public;
revoke execute on function create_case_from_sos(uuid) from public;
revoke execute on function submit_triage(jsonb) from public;
revoke execute on function advocate_search(text, text, text, numeric, text) from public;
revoke execute on function request_update(uuid) from public;
revoke execute on function next_invoice_no(uuid) from public;
revoke execute on function create_invoice(uuid, jsonb, date) from public;
revoke execute on function publish_ai_summary(uuid, text, text) from public;

grant execute on function complete_signup(user_role, text, text) to authenticated;
grant execute on function accept_sos(uuid) to authenticated;
grant execute on function submit_triage(jsonb) to authenticated;
grant execute on function advocate_search(text, text, text, numeric, text) to authenticated;
grant execute on function request_update(uuid) to authenticated;
grant execute on function create_invoice(uuid, jsonb, date) to authenticated;
grant execute on function publish_ai_summary(uuid, text, text) to authenticated;

-- Cron bodies: scheduler-only access rules applied here.
revoke execute on function expire_drafts() from public;
revoke execute on function escalate_pending_checklists() from public;
revoke execute on function expire_sos() from public;
revoke execute on function purge_triage_inputs() from public;
revoke execute on function send_overdue_invoice_reminders() from public;
revoke execute on function annual_reverify_reminder() from public;