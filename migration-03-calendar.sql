-- Pit Wall — Calendar feature migration (mobile app)
-- Run this once in Supabase: Project -> SQL Editor -> New query -> paste this whole file -> Run.
-- Safe to re-run.

-- ========== NEW COLUMNS ==========

alter table teams add column if not exists color text;
alter table events add column if not exists type text not null default 'race' check (type in ('race','test'));
alter table events add column if not exists my_car text;

-- ========== TRAVEL TABLE ==========

create table if not exists travel (
  id text primary key,
  team_id text references teams(id) on delete set null,
  kind text not null default 'travel' check (kind in ('flight','hotel','rental','travel')),
  title text not null,
  start_date date,
  end_date date,
  confirmation text,
  location text,
  notes text,
  updated_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_travel_updated_at on travel;
create trigger trg_travel_updated_at before update on travel for each row execute function set_updated_at();

alter table travel enable row level security;
drop policy if exists "anon full access" on travel;
create policy "anon full access" on travel for all using (true) with check (true);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'travel'
  ) then
    execute 'alter publication supabase_realtime add table travel';
  end if;
end $$;
