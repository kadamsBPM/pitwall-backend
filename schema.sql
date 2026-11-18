-- Pit Wall — Supabase schema + data migration
-- Run this once in Supabase: Project -> SQL Editor -> New query -> paste this whole file -> Run.
-- Safe to re-run: uses IF NOT EXISTS / ON CONFLICT where it matters.

-- ========== TABLES ==========

create table if not exists teams (
  id text primary key,
  name text not null,
  contact text,
  work_day_rate numeric,
  travel_day_rate numeric,
  per_diem text,
  expense_policy text,
  invoice_method text,
  payment_method text,
  notes text,
  updated_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists events (
  id text primary key,
  team_id text references teams(id) on delete set null,
  series text,
  event_name text not null,
  location text,
  start_date date,
  end_date date,
  status text not null default 'tentative' check (status in ('tentative','confirmed','completed')),
  work_days numeric,
  travel_days numeric,
  notes text,
  updated_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists income (
  id text primary key,
  event_id text references events(id) on delete set null,
  team_id text references teams(id) on delete set null,
  date_worked date,
  amount numeric,
  status text not null default 'Not invoiced' check (status in ('Not invoiced','Invoiced','Paid')),
  date_paid date,
  invoice_number text,
  days numeric,
  day_rate numeric,
  notes text,
  updated_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists expenses (
  id text primary key,
  event_id text references events(id) on delete set null,
  date date,
  category text,
  vendor text,
  amount numeric,
  miles_driven numeric,
  receipt_saved text,
  reimbursed_by_team text not null default 'No' check (reimbursed_by_team in ('No','Yes','Partly')),
  notes text,
  updated_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists tasks (
  id text primary key,
  title text not null,
  due_date date,
  category text,
  status text not null default 'To do' check (status in ('To do','In progress','Confirm with CPA','Done')),
  related_event_id text references events(id) on delete set null,
  notes text,
  updated_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Keep updated_at current on every change.
create or replace function set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_teams_updated_at on teams;
create trigger trg_teams_updated_at before update on teams for each row execute function set_updated_at();
drop trigger if exists trg_events_updated_at on events;
create trigger trg_events_updated_at before update on events for each row execute function set_updated_at();
drop trigger if exists trg_income_updated_at on income;
create trigger trg_income_updated_at before update on income for each row execute function set_updated_at();
drop trigger if exists trg_expenses_updated_at on expenses;
create trigger trg_expenses_updated_at before update on expenses for each row execute function set_updated_at();
drop trigger if exists trg_tasks_updated_at on tasks;
create trigger trg_tasks_updated_at before update on tasks for each row execute function set_updated_at();

-- ========== ROW LEVEL SECURITY ==========
-- MVP policy: anyone holding the app's anon key can read/write everything.
-- That key ends up embedded in the compiled app, so this is fine ONLY while
-- you're the sole tester. BEFORE inviting crew or distributing the app
-- further, replace these with auth-scoped policies (e.g. require
-- auth.uid() is not null, or check against a crew membership table).

alter table teams enable row level security;
alter table events enable row level security;
alter table income enable row level security;
alter table expenses enable row level security;
alter table tasks enable row level security;

drop policy if exists "anon full access" on teams;
create policy "anon full access" on teams for all using (true) with check (true);
drop policy if exists "anon full access" on events;
create policy "anon full access" on events for all using (true) with check (true);
drop policy if exists "anon full access" on income;
create policy "anon full access" on income for all using (true) with check (true);
drop policy if exists "anon full access" on expenses;
create policy "anon full access" on expenses for all using (true) with check (true);
drop policy if exists "anon full access" on tasks;
create policy "anon full access" on tasks for all using (true) with check (true);

-- ========== SEED DATA (migrated from Pit Wall / the original Entities Tracker) ==========

insert into teams (id, name, contact, work_day_rate, travel_day_rate, per_diem, expense_policy, invoice_method, payment_method, notes) values
('tpc-racing', 'TPC Racing', 'Harris Levitas', 600, 300, 'None',
 'Reimburses any expense. TPC normally pays hotels, flights and other major costs ahead of time; Kevin''s own spend is mostly food and small items under $75 on his card.',
 'Text to Harris, with a PDF invoice kept as backup', 'Zelle or PayPal',
 'Informal. No 2026 payments in PayPal as of Nov 12, 2026.'),
('flying-lizard', 'Flying Lizard Motorsports', 'flyinglizard@bill.com', 500, 250, 'Set per trip ($140 for Road America)',
 'Team books flights, rental car and hotel; other costs billed back',
 'PDF invoice through Bill.com', 'Bill.com ePayment',
 'Instant Transfer cost $39.74 on invoice 015. One event in 2026.')
on conflict (id) do update set
  name = excluded.name, contact = excluded.contact, work_day_rate = excluded.work_day_rate,
  travel_day_rate = excluded.travel_day_rate, per_diem = excluded.per_diem,
  expense_policy = excluded.expense_policy, invoice_method = excluded.invoice_method,
  payment_method = excluded.payment_method, notes = excluded.notes;

insert into events (id, team_id, series, event_name, location, start_date, end_date, status, work_days, travel_days, notes) values
('evt-fl-2026-road-america', 'flying-lizard', 'SRO', 'Road America', 'Road America', '2026-08-26', '2026-08-30', 'completed', 5, 1,
 'Team booked flights, rental car and hotel.'),
('evt-tpc-2026-daytona', 'tpc-racing', null, 'Daytona International Speedway', 'Daytona International Speedway', '2026-11-09', '2026-11-15', 'confirmed', 6, 1,
 'TPC paid the flight and rental car. Kevin has a $200 rental deposit on his own card, refundable at turn-in (not an expense unless it is kept). Fuel to be billed back.')
on conflict (id) do update set
  team_id = excluded.team_id, series = excluded.series, event_name = excluded.event_name,
  location = excluded.location, start_date = excluded.start_date, end_date = excluded.end_date,
  status = excluded.status, work_days = excluded.work_days, travel_days = excluded.travel_days, notes = excluded.notes;

insert into income (id, event_id, team_id, date_worked, amount, status, date_paid, invoice_number, days, day_rate, notes) values
('inc-015', 'evt-fl-2026-road-america', 'flying-lizard', '2026-08-26', 3179.25, 'Paid', '2026-09-17', '015', 5, 500,
 '5 work days Aug 26-30 at $500, 1 travel day $250, per diem $140, plus airport parking $108.12 and event credential $181.13 billed back. Deposit was $3,139.51 after a $39.74 Instant Transfer fee.'),
('inc-016', 'evt-tpc-2026-daytona', 'tpc-racing', '2026-11-10', null, 'Not invoiced', null, '016 (draft)', 6, 600,
 'Draft invoice 016: 6 work days Nov 10-15 at $600 plus 1 travel day (Nov 9) at $300 = $3,900 before expenses. Amount to be entered when the invoice is final.')
on conflict (id) do update set
  event_id = excluded.event_id, team_id = excluded.team_id, date_worked = excluded.date_worked,
  amount = excluded.amount, status = excluded.status, date_paid = excluded.date_paid,
  invoice_number = excluded.invoice_number, days = excluded.days, day_rate = excluded.day_rate, notes = excluded.notes;

insert into expenses (id, event_id, date, category, vendor, amount, miles_driven, receipt_saved, reimbursed_by_team, notes) values
('exp-fl-parking', 'evt-fl-2026-road-america', '2026-08-26', 'Other', 'Airport parking', 108.12, null, null, 'Yes',
 'Billed back on Bill.com invoice 015. Exact date not shown on the invoice; event start date used.'),
('exp-fl-credential', 'evt-fl-2026-road-america', '2026-08-26', 'Licenses and credentials', 'Single event credential', 181.13, null, null, 'Yes',
 'Billed back on Bill.com invoice 015. Exact date not shown on the invoice; event start date used.'),
('exp-fl-transferfee', 'evt-fl-2026-road-america', '2026-09-17', 'Other', 'Bill.com Instant Transfer fee', 39.74, null, null, 'No',
 'Fee taken from the invoice 015 payout (Bill.com payment P26091702 - 5579199).')
on conflict (id) do update set
  event_id = excluded.event_id, date = excluded.date, category = excluded.category, vendor = excluded.vendor,
  amount = excluded.amount, miles_driven = excluded.miles_driven, receipt_saved = excluded.receipt_saved,
  reimbursed_by_team = excluded.reimbursed_by_team, notes = excluded.notes;

insert into tasks (id, title, due_date, category, status, related_event_id, notes) values
('task-rebuild-2026-records', 'Rebuild 2026 race income and expense records before year-end', '2026-12-31', 'Admin', 'To do', null,
 'Pull deposits, travel receipts and mileage for every 2026 event into Income and Expenses.'),
('task-q4-2026-est-tax', 'Q4 2026 estimated tax payment (federal and Kentucky)', '2027-01-15', 'Tax', 'Confirm with CPA', null,
 'Applies if no tax is withheld from race pay and you expect to owe.'),
('task-1099-due', '2026 Form 1099-NEC due from each team', '2027-02-01', 'Tax', 'To do', null,
 'Check each one against Income. The income is taxable even if no form arrives.'),
('task-personal-return-2026', '2026 personal return with Schedule C for race work, plus Q1 2027 estimate', '2027-04-15', 'Tax', 'To do', null,
 'Hand the CPA the Income and Expenses records.'),
('task-q2-2027-est-tax', 'Q2 2027 estimated tax payment', '2027-06-15', 'Tax', 'To do', null, null),
('task-q3-2027-est-tax', 'Q3 2027 estimated tax payment', '2027-09-15', 'Tax', 'To do', null, null),
('task-send-invoice-016', 'Finalize and send invoice 016 to TPC Racing (Daytona)', null, 'Invoice', 'To do', 'evt-tpc-2026-daytona',
 'Confirm final days/expenses, then invoice via text to Harris.'),
('task-contracts-on-file', 'Collect contracts or day-rate agreements with each team', null, 'Documents', 'To do', null, null),
('task-w9-given', 'Give a current W-9 to each team', null, 'Documents', 'To do', null, null),
('task-mileage-log', 'Keep receipts and mileage log current', null, 'Documents', 'To do', null, null)
on conflict (id) do update set
  title = excluded.title, due_date = excluded.due_date, category = excluded.category, status = excluded.status,
  related_event_id = excluded.related_event_id, notes = excluded.notes;

-- ========== REALTIME ==========
-- Lets the app subscribe to live changes (so e.g. a teammate's edit shows up
-- on your screen without refreshing). Supabase's `supabase_realtime`
-- publication must include these tables. Wrapped so re-running this file
-- doesn't error on tables already added.
do $$
declare
  t text;
begin
  foreach t in array array['teams','events','income','expenses','tasks'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table %I', t);
    end if;
  end loop;
end $$;
