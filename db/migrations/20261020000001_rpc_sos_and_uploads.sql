-- db/migrations/20261020000001_rpc_sos_and_uploads.sql
-- Sprint 2 Task S2-R1: submit_document RPC + private storage buckets.
-- Sources: SHAFAT_tasks.md §S2-R1; database_schema_and_rls.md §2.10, §3, §6;
-- sprint.md Iron Laws #5, #7.
--
-- Migration 009 provisions the documents/sanad buckets (public=false) and
-- storage policies docs_read/docs_write (WITH CHECK), sanad_write (WITH CHECK),
-- sanad_admin_read. This migration re-affirms bucket privacy and adds the
-- submit_document() SECURITY DEFINER RPC.
--
-- Storage path conventions (TRD §5.8):
--   documents/{case_id}/{doc_id}/{filename}
--   sanad/{advocate_id}/sanad.{ext}
-- Signed URL expiry baseline: 900 seconds (15 minutes), enforced by client.

-- =====================================================================
-- 1) Bucket privacy: documents + sanad strictly private.
--    Idempotent UPDATE; migration 009 inserts the buckets with on conflict.
-- =====================================================================
update storage.buckets
   set public = false,
       file_size_limit = 52428800,
       allowed_mime_types = array[
         'application/pdf',
         'image/png',
         'image/jpeg',
         'image/jpg'
       ]
 where id in ('documents', 'sanad');

-- =====================================================================
-- 2) RPC submit_document — case-party guarded document upload record.
--    Security: SECURITY DEFINER, search_path = public, revoke public.
-- =====================================================================
create or replace function submit_document(
  p_case_id uuid,
  p_doc_type text,
  p_storage_path text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_doc_id uuid;
begin
  if not has_case_access(p_case_id) then
    raise exception 'unauthorized_case_access';
  end if;

  insert into documents (case_id, uploaded_by, doc_type, storage_path, status)
  values (p_case_id, auth.uid(), p_doc_type, p_storage_path, 'uploaded')
  returning id into v_doc_id;

  insert into audit_logs (actor_id, actor_role, action, entity, entity_id, metadata)
  values (
    auth.uid(),
    (select role from profiles where id = auth.uid()),
    'document.upload',
    'documents',
    v_doc_id,
    jsonb_build_object('case_id', p_case_id, 'doc_type', p_doc_type, 'storage_path', p_storage_path)
  );

  return v_doc_id;
end $$;

revoke execute on function submit_document(uuid, text, text) from public;
grant execute on function submit_document(uuid, text, text) to authenticated;

-- =====================================================================
-- 3) Storage RLS policies on storage.objects (S2-R6 / Iron Law #5).
--    INSERT policies use WITH CHECK (never USING alone). SELECT uses USING.
--    No UPDATE or DELETE policies: storage objects are immutable append-only.
-- =====================================================================

alter table storage.objects enable row level security;

drop policy if exists documents_insert_policy on storage.objects;
create policy documents_insert_policy on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'documents'
    and has_case_access((storage.foldername(name))[1]::uuid)
  );

drop policy if exists documents_select_policy on storage.objects;
create policy documents_select_policy on storage.objects
  for select to authenticated
  using (
    bucket_id = 'documents'
    and has_case_access((storage.foldername(name))[1]::uuid)
  );

drop policy if exists sanad_insert_policy on storage.objects;
create policy sanad_insert_policy on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'sanad'
    and (storage.foldername(name))[1]::uuid = auth.uid()
  );

drop policy if exists sanad_select_policy on storage.objects;
create policy sanad_select_policy on storage.objects
  for select to authenticated
  using (
    bucket_id = 'sanad'
    and (
      (storage.foldername(name))[1]::uuid = auth.uid()
      or exists (
        select 1 from profiles
        where profiles.id = auth.uid() and profiles.role = 'admin'
      )
    )
  );
