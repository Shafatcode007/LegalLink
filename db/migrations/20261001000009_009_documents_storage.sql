-- db/migrations/20261004_009_documents_storage.sql
-- Sprint 1: documents vault + storage buckets + storage policies.
-- Sources: TRD sections 5.4 (documents DDL), 5.8 (buckets + storage policy
-- example), database_schema section 2.9 (documents entry).
-- Ruling m: the documents with check is made symmetric with the using
-- clause — `and deleted_at is null` added, so a client cannot insert a row
-- already marked deleted.
-- Storage buckets (documents: private; sanad: private; avatars: public).

create table documents (
  id               uuid primary key default gen_random_uuid(),
  case_id          uuid not null references cases(id),
  checklist_item_id uuid references checklist_items(id),
  uploaded_by      uuid not null references profiles(id),
  doc_type         text not null,            -- fir|arrest_memo|nid|invoice_proof|order|other
  storage_path     text,                     -- null while offline-local only
  local_ref        text,                     -- device-local reference (F8 rule)
  mime_type        text, size_bytes bigint,
  status           doc_status not null default 'uploaded',
  reject_reason    text,
  deleted_at       timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

alter table documents enable row level security;

-- documents: case parties; storage access via signed URLs only.
-- Ruling m: with check mirrors the using clause (case_id/has_case_access/deleted_at).
create policy documents_party on documents for all
  using (case_id is not null and has_case_access(case_id) and deleted_at is null)
  with check (uploaded_by = auth.uid() and case_id is not null
              and has_case_access(case_id) and deleted_at is null);

-- Storage buckets (TRD section 5.8 path conventions).
insert into storage.buckets (id, name, public)
values ('documents', 'documents', false),
       ('sanad', 'sanad', false),
       ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- documents bucket: read + write gated on case access from the object path.
create policy docs_read on storage.objects for select
using (
  bucket_id = 'documents'
  and has_case_access((storage.foldername(name))[1]::uuid)
);
create policy docs_write on storage.objects for insert
with check (
  bucket_id = 'documents'
  and has_case_access((storage.foldername(name))[1]::uuid)
);

-- sanad bucket: advocates write only their own file; only admins read it back.
create policy sanad_write on storage.objects for insert
with check (
  bucket_id = 'sanad'
  and (storage.foldername(name))[1] = auth.uid()::text
);
create policy sanad_admin_read on storage.objects for select
using (
  bucket_id = 'sanad'
  and is_admin()
);

-- avatars bucket: owner writes their own file; public reads it.
create policy avatars_write on storage.objects for insert
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);
create policy avatars_public_read on storage.objects for select
using (bucket_id = 'avatars');