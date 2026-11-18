-- Pit Wall mobile — receipt capture migration
-- Run this once in Supabase: Project -> SQL Editor -> New query -> paste -> Run.
-- Adds a column to point an expense at its receipt photo, and a storage
-- bucket to hold those photos. Safe to re-run.

-- Column to store the Supabase Storage path of a scanned receipt photo.
alter table expenses add column if not exists receipt_path text;

-- Storage bucket for receipt photos.
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', true)
on conflict (id) do nothing;

-- MVP policy: same posture as schema.sql — anyone holding the app's anon
-- key can read/write this bucket. Tighten alongside the table policies
-- before this goes beyond you alone (see the security note in schema.sql
-- and the mobile app's README).
drop policy if exists "anon full access to receipts" on storage.objects;
create policy "anon full access to receipts" on storage.objects
  for all using (bucket_id = 'receipts') with check (bucket_id = 'receipts');
