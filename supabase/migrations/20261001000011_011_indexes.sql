-- db/migrations/20261006_011_indexes.sql
-- Sprint 1: every index from TRD section 5.5, verbatim.
-- Ruling c (second half): partial unique on hearings.supersedes_id lives in
-- 005 with the immutability trigger; ruling i (triage partial unique) lives
-- in 010. This file is the doc's index list only.
-- Foreign keys from 002-010 that carry an RLS predicate or join load and
-- lack a dedicated doc index get one here (profiles phone for OTP lookup is
-- handled by auth, not the app schema).

-- Advocate discovery (PRD F2): filter by district/court/specialization
create index advocates_districts_gin   on advocates using gin (districts);
create index advocates_courts_gin      on advocates using gin (courts);
create index advocates_spec_gin        on advocates using gin (specializations);
create index advocates_verified_idx    on advocates (verification) where verification = 'verified';

-- SOS live queue (advocates subscribe per district)
create index sos_open_by_district on sos_requests (district, created_at desc)
  where status = 'open';
create index sos_client_recent on sos_requests (client_id, created_at desc);  -- rate limiting

-- Case and timeline access (RLS predicates)
create index cases_client_idx   on cases (client_id, state);
create index cases_advocate_idx on cases (advocate_id, state);
create index hearings_case_idx  on hearings (case_id, hearing_date desc);
create index hearings_next_idx  on hearings (next_hearing_date) where published_at is not null;

-- HITL queues and sweeps
create index summaries_draft_expiry on ai_summaries (expires_at) where state = 'draft';
create index summaries_case_idx     on ai_summaries (case_id, state);

-- Checklists
create index checklist_case_idx    on checklist_items (case_id, status);
create index checklist_pending_idx on checklist_items (approved_at)
  where status = 'suggested_pending_advocate';   -- 48h escalation sweep

-- Billing
create index invoices_case_idx     on invoices (case_id, state);
create index invoices_due_idx      on invoices (due_date) where state in ('sent','partially_paid');
create index payments_invoice_idx  on payments (invoice_id);

-- Documents / triage / audit
create index documents_case_idx    on documents (case_id) where deleted_at is null;
create index triage_user_day_idx   on ai_triage_sessions (user_id, created_at desc); -- rate limit
create index audit_entity_idx      on audit_logs (entity, entity_id, created_at desc);
create index audit_actor_idx       on audit_logs (actor_id, created_at desc);

-- RAG (P1)
-- TODO: RAG P1 - create index lkb_embedding_idx on legal_knowledge_base
--   using hnsw (embedding vector_cosine_ops)

-- RLS join predicates with no dedicated doc index: pin/guard lookups and
-- notification fan-out stay index-friendly via their PKs; no extra indexes.
