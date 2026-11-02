-- Sprint 2 (Role C): broadcast sos_requests changes for the sos:{district}
-- channel (TRD §6.5, docs/push&commit_rules.md §1.3).
--
-- Supabase Realtime only streams tables in the supabase_realtime
-- publication. postgres_changes then applies each subscriber's RLS, so an
-- advocate receives only rows sos_advocate_select_open lets them read:
-- open SOS in their own districts, verified advocates only.
--
-- No table, column or policy changes.

alter publication supabase_realtime add table sos_requests;
