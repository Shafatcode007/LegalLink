-- db/seed.sql
-- LegalLink test/demo seed. Run against a FRESH local database only:
--   supabase db reset
--   psql -v ON_ERROR_STOP=1 "$LOCAL_DB_URL" -f db/seed.sql
-- Not idempotent by design. Never run against staging or prod.
-- Sources: TRD §5.9 (seed strategy), TRD §13 (test data), TRD §16.2 (G-1.1 run).
--
-- ISOLATION RULES (Round 4):
--   * db/tests/rls_test.sql is self-contained and must NOT depend on this file.
--   * CI (.github/workflows/rls.yml) never loads this file — seed drift must
--     not be able to mask or fabricate an RLS regression.
--
-- GUC RATIONALE (corrected vs Round-4 draft): app.internal_write is REQUIRED
-- for the draft->published UPDATE below — 017's ai_summaries_publish_guard
-- rejects any transition to 'published' without it. It is NOT required for
-- the advocates INSERTs: advocates_pin_guard's INSERT branch only rejects
-- NONZERO pin_fail_count / pin_locked_until, and these rows use column
-- defaults (pin_hash on insert is legitimate — it is the advocate's own
-- initial PIN, settable via set_publish_pin as well). `set local` dies with
-- this transaction; no session-level leak.
--
-- pgcrypto: search_path includes `extensions` (hosted Supabase installs
-- crypt/gen_salt there; legacy installs keep them in public — both resolve).
-- Same caveat as migration 018: errors only on bare Postgres without it.

begin;

set local search_path = public, extensions;
set local app.internal_write = '1';

-- =====================================================================
-- FIXTURE SHAPE WATCH (Rounds 3-4): auth.users columns vary across
-- Supabase versions. If a version rejects this insert, EDIT THIS BLOCK
-- ONLY; every downstream row references these uuids and nothing else
-- touches auth.users.
-- =====================================================================
insert into auth.users (id, aud, role, phone, raw_app_meta_data, raw_user_meta_data)
values
  ('11111111-1111-1111-1111-111111111101', 'authenticated', 'authenticated',
   '+8801700000001', '{"provider":"phone","providers":["phone"],"role":"client"}', '{}'),
  ('11111111-1111-1111-1111-111111111102', 'authenticated', 'authenticated',
   '+8801700000002', '{"provider":"phone","providers":["phone"],"role":"client"}', '{}'),
  ('11111111-1111-1111-1111-111111111103', 'authenticated', 'authenticated',
   '+8801700000003', '{"provider":"phone","providers":["phone"],"role":"client"}', '{}'),
  ('11111111-1111-1111-1111-111111111201', 'authenticated', 'authenticated',
   '+8801700000201', '{"provider":"phone","providers":["phone"],"role":"advocate"}', '{}'),
  ('11111111-1111-1111-1111-111111111202', 'authenticated', 'authenticated',
   '+8801700000202', '{"provider":"phone","providers":["phone"],"role":"advocate"}', '{}'),
  ('11111111-1111-1111-1111-111111111203', 'authenticated', 'authenticated',
   '+8801700000203', '{"provider":"phone","providers":["phone"],"role":"advocate"}', '{}'),
  ('11111111-1111-1111-1111-111111111301', 'authenticated', 'authenticated',
   '+8801700000301', '{"provider":"phone","providers":["phone"],"role":"admin"}', '{}');

insert into profiles (id, role, full_name, phone, language)
values
  ('11111111-1111-1111-1111-111111111101', 'client',   'ক্লায়েন্ট ক',   '+8801700000001', 'bn'),
  ('11111111-1111-1111-1111-111111111102', 'client',   'ক্লায়েন্ট খ',   '+8801700000002', 'bn'),
  ('11111111-1111-1111-1111-111111111103', 'client',   'ক্লায়েন্ট গ',   '+8801700000003', 'bn'),
  ('11111111-1111-1111-1111-111111111201', 'advocate', 'এডভোকেট রহমান', '+8801700000201', 'bn'),
  ('11111111-1111-1111-1111-111111111202', 'advocate', 'এডভোকেট করিম',  '+8801700000202', 'bn'),
  ('11111111-1111-1111-1111-111111111203', 'advocate', 'এডভোকেট অপেক্ষমাণ', '+8801700000203', 'bn'),
  ('11111111-1111-1111-1111-111111111301', 'admin',    'প্ল্যাটফর্ম অ্যাডমিন', '+8801700000301', 'bn');

-- PIN 1234 for the two verified advocates; hashed, never plain (TRD §9.3).
-- Column check vs §2.2: profile_id, bar_council_no, years_practice,
-- specializations/courts/districts/languages (text[]), fee bounds + table
-- check (max >= min), verification enum, pin_hash — all present.
insert into advocates (
  profile_id, bar_council_no, years_practice, specializations, courts, districts,
  languages, fee_min_bdt, fee_max_bdt, verification, verified_at, reverify_due_at, pin_hash
)
values
  ('11111111-1111-1111-1111-111111111201', 'BC-10001', 12,
   '{bail,criminal}', '{Dhaka CMM Court 1}', '{Dhaka}', '{bn}', 5000, 15000,
   'verified', now(), now() + interval '1 year', crypt('1234', gen_salt('bf', 10))),
  ('11111111-1111-1111-1111-111111111202', 'BC-10002', 7,
   '{criminal,women_child}', '{Dhaka CMM Court 2}', '{Dhaka}', '{bn}', 4000, 12000,
   'verified', now(), now() + interval '1 year', crypt('1234', gen_salt('bf', 10))),
  ('11111111-1111-1111-1111-111111111203', 'BC-10003', 3,
   '{family}', '{Chattogram Family Court}', '{Chattogram}', '{bn}', null, null,
   'pending', null, null, null);

-- cases: case_type is free text (§2.4), state defaults but is set explicitly;
-- parties/transfer_log jsonb have defaults; case_number nullable.
insert into cases (id, client_id, advocate_id, case_type, court, district, state)
values
  ('33333333-3333-3333-3333-333333333301',
   '11111111-1111-1111-1111-111111111101', '11111111-1111-1111-1111-111111111201',
   'bail', 'Dhaka CMM Court 1', 'Dhaka', 'active'),
  ('33333333-3333-3333-3333-333333333302',
   '11111111-1111-1111-1111-111111111102', '11111111-1111-1111-1111-111111111202',
   'criminal', 'Dhaka CMM Court 2', 'Dhaka', 'active'),
  ('33333333-3333-3333-3333-333333333303',
   '11111111-1111-1111-1111-111111111103', null,
   'family', 'Chattogram Family Court', 'Chattogram', 'created');

-- consents.scope is text[] with default '{case_data}' (§2.5) — value matches.
insert into consents (case_id, client_id, advocate_id, scope)
values
  ('33333333-3333-3333-3333-333333333301',
   '11111111-1111-1111-1111-111111111101', '11111111-1111-1111-1111-111111111201', '{case_data}'),
  ('33333333-3333-3333-3333-333333333302',
   '11111111-1111-1111-1111-111111111102', '11111111-1111-1111-1111-111111111202', '{case_data}');

insert into hearings (case_id, hearing_date, court, outcome_notes, next_hearing_date,
                      entered_by, published_at)
values
  ('33333333-3333-3333-3333-333333333301', current_date - 7, 'Dhaka CMM Court 1',
   'জামিন আবেদন দাখিল; বিপক্ষ সময় চেয়েছে।', current_date + 14,
   '11111111-1111-1111-1111-111111111201', now());

-- Draft stays invisible to the client (G-1.1 step 15 probes this row).
insert into ai_summaries (id, case_id, raw_input, draft_bn, state)
values
  ('44444444-4444-4444-4444-444444444401',
   '33333333-3333-3333-3333-333333333301',
   '[REDACTED] notes', 'খসড়া: শুনানি অনুষ্ঠিত, পরবর্তী তারিখ নির্ধারিত।', 'draft');

-- Published row: insert as draft, then transition through the 017 update guard
-- with the GUC set (this UPDATE is what app.internal_write exists for in this
-- file). Positive exercise of the guard; NOT a substitute for the suite's
-- negative assertions.
insert into ai_summaries (id, case_id, raw_input, draft_bn, final_bn, state)
values
  ('44444444-4444-4444-4444-444444444402',
   '33333333-3333-3333-3333-333333333301',
   '[REDACTED] notes', 'খসড়া সারাংশ।',
   '১২ তারিখের শুনানিতে জামিনের আবেদন দাখিল হয়েছে; পরবর্তী শুনানি ১৪ দিন পর।', 'draft');

update ai_summaries
   set state = 'published',
       approved_by = '11111111-1111-1111-1111-111111111201',
       published_by = 'advocate'
 where id = '44444444-4444-4444-4444-444444444402';

-- checklist_templates: verified against TRD DDL — importance check
-- ('high','medium','low'), sort_order/active/created_at defaulted, id defaulted.
insert into checklist_templates (case_type, item_name_bn, item_name_en, importance, purpose_bn, sort_order)
values
  ('bail',   'এফআইআর কপি',                 'FIR copy',                 'high',   'মামলার মূল দলিল', 1),
  ('bail',   'গ্রেপ্তার মেমো',               'Arrest memo',              'high',   'গ্রেপ্তারের আইনি প্রমাণ', 2),
  ('bail',   'গ্রেপ্তার ব্যক্তির এনআইডি',    'Arrested person NID',      'medium', 'পরিচয় যাচাই', 3),
  ('criminal','এফআইআর কপি',                'FIR copy',                 'high',   'অভিযোগের ভিত্তি', 1),
  ('criminal','সাক্ষীর তালিকা',             'Witness list',             'medium', 'সাক্ষ্য প্রস্তুতি', 2),
  ('family',  'বিবাহের কাবিননামা',           'Marriage certificate',     'high',   'মামলার ভিত্তি দলিল', 1),
  ('family',  'ভরণপোষণের হিসাব',           'Maintenance calculation',  'medium', 'দাবির পরিমাণ নির্ধারণ', 2),
  ('property','দলিল/খতিয়ান',               'Deed / khatiyan',          'high',   'মালিকানার প্রমাণ', 1),
  ('property','মৌজা ম্যাপ',                 'Mouza map',                'medium', 'সীমানা নির্ধারণ', 2),
  ('women_child','মেডিকেল রিপোর্ট',          'Medical report',           'high',   'প্রমাণ সংরক্ষণ', 1),
  ('women_child','নিরাপত্তা আবেদন খসড়া',     'Protection application draft','high','জরুরি সুরক্ষা', 2);

-- Per-case instances for the bail case: first item approved, rest pending.
insert into checklist_items (case_id, template_id, item_name_bn, importance, status, approved_by, approved_at)
select '33333333-3333-3333-3333-333333333301', t.id, t.item_name_bn, t.importance,
       case when t.sort_order = 1 then 'approved' else 'suggested_pending_advocate' end,
       case when t.sort_order = 1 then '11111111-1111-1111-1111-111111111201' else null end,
       case when t.sort_order = 1 then now() else null end
  from checklist_templates t
 where t.case_type = 'bail';

commit;

-- Seed complete. Expected: 7 auth users, 7 profiles, 3 advocates (2 verified
-- with PIN 1234, 1 pending), 3 cases, 2 consents, 1 hearing,
-- 2 ai_summaries (1 draft invisible to client, 1 published),
-- 11 checklist templates, 3 checklist items.
-- Optional demo add (not required by TRD §5.9): one open sos_requests row for
-- rehearsing G-4.1 steps 3-5 through the app.
