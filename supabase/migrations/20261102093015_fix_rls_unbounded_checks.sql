-- Fix unbounded INSERT policy on invoice_items
drop policy if exists invoice_items_advocate_write on invoice_items;
create policy invoice_items_advocate_write on invoice_items for all
  using (
    exists (
      select 1 from invoices i
      where i.id = invoice_items.invoice_id
        and i.advocate_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from invoices i
      where i.id = invoice_items.invoice_id
        and i.advocate_id = auth.uid()
        and i.state in ('draft', 'sent')
    )
  );

-- Fix unbounded INSERT policy on checklist_items
drop policy if exists checklist_advocate_rw on checklist_items;
create policy checklist_advocate_rw on checklist_items for all
  using (
    exists (
      select 1 from cases c
      where c.id = checklist_items.case_id
        and c.advocate_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from cases c
      where c.id = checklist_items.case_id
        and c.advocate_id = auth.uid()
    )
  );
