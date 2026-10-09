-- db/migrations/20261003_006_ai_summaries.sql
-- Sprint 1: ai_summaries (HITL state machine base table).
-- Sources: TRD section 5.4 (table), section 5.5 (policies),
--          database_schema section 2.7.
-- Ruling o: policies authored VERBATIM from the doc, INCLUDING the
-- summaries_advocate_all FOR ALL grant. The HITL gate is NOT enforced here:
-- 017's revokes + publish-guard trigger are the fix. Adding a second,
-- competing restriction in this file is explicitly forbidden.

create table ai_summaries (
  id             uuid primary key default gen_random_uuid(),
  case_id        uuid not null references cases(id),
  hearing_id     uuid references hearings(id),
  raw_input      text not null,              -- advocate notes (PII redacted value stored)
  draft_bn       text not null,              -- AI output
  final_bn       text,                       -- advocate-edited final text
  state          summary_state not null default 'draft',
  model          text,                       -- e.g. llama-3.3-70b | qwen2.5-7b-instruct
  prompt_version text,                       -- e.g. summary_v3
  tokens_used    int,
  approved_by    uuid references profiles(id),
  published_by   text,                       -- 'advocate' | 'admin_override'
  override_reason text,
  flagged        boolean not null default false,
  archived_at    timestamptz,                -- 7-day expiry sweep
  expires_at     timestamptz not null default now() + interval '7 days',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  version        int not null default 1
);

alter table ai_summaries enable row level security;

-- ai_summaries: THE HITL GUARANTEE (client can never read a draft)
create policy summaries_client_published on ai_summaries for select
  using (
    state = 'published'
    and exists (select 1 from cases c where c.id = ai_summaries.case_id
                and c.client_id = auth.uid())
  );
create policy summaries_advocate_all on ai_summaries for all
  using (exists (select 1 from cases c where c.id = ai_summaries.case_id
                 and c.advocate_id = auth.uid()))
  with check (exists (select 1 from cases c where c.id = ai_summaries.case_id
                      and c.advocate_id = auth.uid()));
create policy summaries_admin_all on ai_summaries for all
  using (is_admin()) with check (is_admin());
