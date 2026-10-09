-- 014: cron function bodies (TRD §5.7). All security definer, own where-clauses,
-- dedupe-safe notification inserts. Ruling k: overdue reminders anchor on due_date.

create or replace function expire_drafts() returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into notifications(user_id, kind, title_bn, body_bn, dedupe_key)
  select c.advocate_id, 'summary.draft_expired',
         'সারাংশ প্রকাশের সময় শেষ',
         'একটি খসড়া সারাংশের মেয়াদ শেষ হয়েছে; নতুন সারাংশ তৈরি করুন।',
         'draft_expired:' || s.id
    from ai_summaries s
    join cases c on c.id = s.case_id
   where s.state = 'draft' and s.expires_at < now()
  on conflict (dedupe_key) do nothing;

  update ai_summaries
     set state = 'archived', archived_at = now()
   where state = 'draft' and expires_at < now();
end $$;

create or replace function escalate_pending_checklists() returns void
language plpgsql security definer set search_path = public as $$
begin
  -- Advocate reminder: review overdue suggested items (daily key, hourly cron).
  insert into notifications(user_id, kind, title_bn, body_bn, dedupe_key)
  select c.advocate_id, 'checklist.escalate_reminder',
         'নথি তালিকা অনুমোদন করুন',
         '৪৮ ঘণ্টার বেশি সময় ধরে নথি তালিকা অপেক্ষমাণ; অনুগ্রহ করে পর্যালোচনা করুন।',
         'checklist_esc:' || c.id || ':' || date_trunc('day', now())::date
    from cases c
   where c.advocate_id is not null
     and exists (select 1 from checklist_items ci
                  where ci.case_id = c.id
                    and ci.status = 'suggested_pending_advocate'
                    and ci.created_at < now() - interval '48 hours')
  on conflict (dedupe_key) do nothing;

  -- Client notice: checklist now behaves as the general list with disclaimer.
  insert into notifications(user_id, kind, title_bn, body_bn, dedupe_key)
  select c.client_id, 'checklist.general_mode',
         'সাধারণ নথি তালিকা',
         'এটি একটি সাধারণ তালিকা। অনুগ্রহ করে একজন যাচাইকৃত উকিলের সাথে যোগাযোগ করুন।',
         'checklist_gen:' || c.id || ':' || date_trunc('day', now())::date
    from cases c
   where exists (select 1 from checklist_items ci
                  where ci.case_id = c.id
                    and ci.status = 'suggested_pending_advocate'
                    and ci.created_at < now() - interval '48 hours')
  on conflict (dedupe_key) do nothing;
end $$;

create or replace function expire_sos() returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into notifications(user_id, kind, title_bn, body_bn, dedupe_key)
  select s.client_id, 'sos.expired',
         'SOS-এর সময় শেষ',
         '২৪ ঘণ্টায় কোনো উকিল গ্রহণ করেননি; সম্পাদনা করে আবার পাঠান বা উকিল খুঁজুন।',
         'sos_expired:' || s.id
    from sos_requests s
   where s.status = 'open' and s.expires_at < now()
  on conflict (dedupe_key) do nothing;

  update sos_requests
     set status = 'expired'
   where status = 'open' and expires_at < now();
end $$;

create or replace function purge_triage_inputs() returns void
language plpgsql security definer set search_path = public as $$
begin
  update ai_triage_sessions
     set input_redacted = null
   where created_at < now() - interval '30 days'
     and input_redacted is not null;
end $$;

create or replace function send_overdue_invoice_reminders() returns void
language plpgsql security definer set search_path = public as $$
begin
  -- 1) State transition: past due + 3 days => overdue (from sent/partially_paid).
  update invoices
     set state = 'overdue'
   where state in ('sent', 'partially_paid')
     and due_date is not null
     and (current_date - due_date) >= 3;

  -- 2) Client reminders at exactly 3, 7 and 14 days overdue (due_date anchor).
  insert into notifications(user_id, kind, title_bn, body_bn, payload, dedupe_key)
  select i.client_id, 'invoice.overdue_reminder',
         'ইনভয়েস বকেয়া',
         'আপনার একটি ইনভয়েস বকেয়া আছে; অনুগ্রহ করে পরিশোধ করুন।',
         jsonb_build_object('invoice_id', i.id, 'days_overdue', (current_date - i.due_date)),
         'inv_rem:' || i.id || ':' || (current_date - i.due_date)
    from invoices i
   where i.state in ('overdue', 'partially_paid')
     and i.due_date is not null
     and (current_date - i.due_date) in (3, 7, 14)
  on conflict (dedupe_key) do nothing;

  -- 3) At 30 days: flag for the advocate (once per invoice).
  insert into notifications(user_id, kind, title_bn, body_bn, payload, dedupe_key)
  select i.advocate_id, 'invoice.escalated',
         'ইনভয়েস ৩০ দিন বকেয়া',
         'একটি ইনভয়েস ৩০ দিনের বেশি বকেয়া; ক্লায়েন্টের সাথে যোগাযোগ করুন।',
         jsonb_build_object('invoice_id', i.id),
         'inv_esc:' || i.id
    from invoices i
   where i.state in ('overdue', 'partially_paid')
     and i.due_date is not null
     and (current_date - i.due_date) >= 30
  on conflict (dedupe_key) do nothing;
end $$;

-- annual_reverify_reminder: body verbatim from TRD §5.7 (IM-2).
create or replace function annual_reverify_reminder() returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into notifications(user_id, kind, title_bn, body_bn, dedupe_key)
  select a.profile_id, 'advocate.reverify_due',
         'বার কাউন্সিল যাচাই নবায়ন করুন',
         'আপনার সনদ বার্ষিক যাচাইয়ের সময় হয়েছে।',
         'reverify:' || a.profile_id || ':' || date_trunc('day', now())::date
    from advocates a
   where a.verification = 'verified'
     and a.reverify_due_at between now() and now() + interval '30 days';

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
end $$;
