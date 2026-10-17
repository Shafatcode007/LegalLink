-- db/migrations/20261020000001_sanad_storage_rpc.sql
-- Sprint 2 (Task 1): harden the private `sanad` bucket + document-URL RPC.
--
-- Context: migration 009 already provisioned the private `sanad` bucket
-- (public = false) and the `sanad_write` (INSERT, own folder) and
-- `sanad_admin_read` (SELECT, is_admin()) policies. The gaps closed here:
--   1. `sanad_write` did not require the caller to be an ADVOCATE, so any
--      authenticated client could write into their own {uid}/ folder. An
--      ADDITIVE restrictive policy now enforces role = 'advocate' for the
--      sanad bucket only; no existing policy clause is altered (gate §3.2).
--   2. `update_advocate_documents(...)` persists uploaded object paths on the
--      caller's own `advocates` row and emits `advocate.upload_credentials`.
--
-- Iron Laws: INSERT policies use WITH CHECK; SECURITY DEFINER sets
-- search_path and revokes public execute.
-- Path convention (TRD §5.8): {advocate_id}/sanad.{ext}, {advocate_id}/nid.{ext}.

-- =====================================================================
-- 1) Restrictive role gate on sanad writes.
--    Restrictive policies AND with every permissive INSERT policy on the
--    table, so the `bucket_id <> 'sanad'` guard keeps documents/ and
--    avatars/ inserts untouched while sanad inserts require role='advocate'.
-- =====================================================================
create policy sanad_insert_advocate_only on storage.objects
  as restrictive for insert
  with check (
    bucket_id <> 'sanad'
    or (select p.role from profiles p where p.id = auth.uid()) = 'advocate'
  );

-- =====================================================================
-- 2) Persist uploaded document paths (Sanad + NID) for the caller.
--    RPC-only mutation: advocates cannot PATCH the URL columns directly
--    without going through this audited path.
-- =====================================================================
create or replace function update_advocate_documents(
  p_sanad_url text,
  p_nid_url text
)
returns advocates
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_row advocates;
  v_actor_role user_role;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;

  select role into v_actor_role from profiles where id = auth.uid();
  if v_actor_role <> 'advocate' then
    raise exception 'caller must have advocate role';
  end if;

  if p_sanad_url is null and p_nid_url is null then
    raise exception 'no_documents_provided';
  end if;

  update advocates
     set sanad_url = coalesce(p_sanad_url, sanad_url),
         nid_url   = coalesce(p_nid_url, nid_url),
         updated_at = now()
   where profile_id = auth.uid()
   returning * into v_row;

  if not found then
    raise exception 'advocate_not_found';
  end if;

  insert into audit_logs (actor_id, actor_role, action, entity, entity_id, metadata)
  values (
    auth.uid(), v_actor_role, 'advocate.upload_credentials',
    'advocates', auth.uid(),
    jsonb_build_object('sanad_url', p_sanad_url, 'nid_url', p_nid_url)
  );

  return v_row;
end $$;

revoke execute on function update_advocate_documents(text, text) from public;
grant execute on function update_advocate_documents(text, text) to authenticated;
