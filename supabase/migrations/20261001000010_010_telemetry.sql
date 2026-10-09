-- db/migrations/20261005_010_telemetry.sql
-- Sprint 1: ai_triage_sessions (telemetry) + audit_logs (append-only record)
-- + notifications (push/in-app messages).
-- Sources: TRD section 5.4 (all three DDLs + RLS), database_schema
-- section 2.9 (ai_triage_sessions, audit_logs, notifications entries).
-- Ruling i: a second triage session for the same case must be impossible —
-- partial unique index on case_id where case_id is not null.
-- Ruling g: append-only needs more than RLS deny-by-default — a BEFORE
-- UPDATE OR DELETE trigger raising audit_immutable makes service_role and
-- owner paths structurally incapable of rewriting history too.

create table ai_triage_sessions (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references profiles(id),
  case_id        uuid references cases(id),
  input_hash     text not null,           -- sha256 of the raw (pre-redaction) input
  input_redacted text not null,           -- what we actually sent to the LLM
  output_json    jsonb not null,          -- {case_type, urgency, overview, actions[], checklist[]}
  model          text, prompt_version text, tokens_used int,
  fallback_used  boolean not null default false,
  created_at     timestamptz not null default now()
);

-- Ruling i: one triage per case — prevents double checklist instantiation.
create unique index triage_case_unique on ai_triage_sessions (case_id)
  where case_id is not null;

alter table ai_triage_sessions enable row level security;

create policy triage_self on ai_triage_sessions for all
  using (user_id = auth.uid() or is_admin())
  with check (user_id = auth.uid());

create table audit_logs (
  id         bigserial primary key,
  actor_id   uuid references profiles(id),
  actor_role user_role,
  action     text not null,         -- sos.accept | summary.publish | admin.override | ...
  entity     text, entity_id uuid,
  metadata   jsonb not null default '{}'::jsonb,
  ip         inet, device text,
  created_at timestamptz not null default now()
);
-- no UPDATE/DELETE policy is ever created for this table

alter table audit_logs enable row level security;

create policy audit_admin_read on audit_logs for select using (is_admin());

-- Ruling g: structural append-only — triggers fire regardless of role,
-- so even service_role / owner paths cannot rewrite the audit trail.
create or replace function audit_immutable() returns trigger
language plpgsql as $$
begin
  raise exception 'audit_immutable';
end $$;

drop trigger if exists audit_immutable on audit_logs;
create trigger audit_immutable
  before update or delete on audit_logs
  for each row execute function audit_immutable();

create table notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id),
  kind        text not null,     -- sos.accepted | checklist.approved | hearing.reminder | ...
  title_bn    text, body_bn text,
  payload     jsonb not null default '{}'::jsonb,
  channel     text not null default 'push',   -- push | in_app
  sent_at     timestamptz, read_at timestamptz,
  dedupe_key  text unique,       -- prevents duplicate reminder storms
  created_at  timestamptz not null default now()
);

alter table notifications enable row level security;

create policy notifications_self on notifications for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
