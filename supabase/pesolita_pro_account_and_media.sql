-- Pesolita Pro — account deletion and private backup photos.
--
-- Run in the Supabase dashboard for project exapqjxrptjhvvbcnrdr:
--   SQL Editor → New query → paste PART 1 → Run.
-- PART 2 only after most people are on Pesolita 1.7 (see the note there).
--
-- Folder names in the `media` bucket are the user's id as the iPhone writes it (UPPERCASE),
-- while auth.uid()::text is lowercase, so every comparison below lowercases the folder.


-- ═══ PART 1 — safe to run now ═══════════════════════════════════════════════════════════

-- "Delete backup & account" in the app. The app first removes the user's photos through the
-- Storage API (Supabase no longer allows deleting storage rows from SQL), then calls this to
-- remove the wallet backup and the sign-in account itself.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not signed in';
  end if;
  delete from public.snapshots where user_id = uid;
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- Each signed-in user can read, add, replace and delete only files in their own folder.
-- Needed for PART 2, and harmless before it: uploads already go to the user's own folder.
drop policy if exists "pesolita media: owner reads" on storage.objects;
create policy "pesolita media: owner reads" on storage.objects
  for select to authenticated
  using (bucket_id = 'media' and lower((storage.foldername(name))[1]) = auth.uid()::text);

drop policy if exists "pesolita media: owner uploads" on storage.objects;
create policy "pesolita media: owner uploads" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'media' and lower((storage.foldername(name))[1]) = auth.uid()::text);

drop policy if exists "pesolita media: owner replaces" on storage.objects;
create policy "pesolita media: owner replaces" on storage.objects
  for update to authenticated
  using (bucket_id = 'media' and lower((storage.foldername(name))[1]) = auth.uid()::text);

drop policy if exists "pesolita media: owner deletes" on storage.objects;
create policy "pesolita media: owner deletes" on storage.objects
  for delete to authenticated
  using (bucket_id = 'media' and lower((storage.foldername(name))[1]) = auth.uid()::text);

-- Check afterwards: any OTHER policy on storage.objects for bucket 'media' that allows `anon`
-- or everyone to select would keep photos readable after PART 2. List them with:
--   select policyname, roles, cmd, qual from pg_policies
--   where schemaname = 'storage' and tablename = 'objects';


-- ═══ PART 2 — make backup photos private ═══════════════════════════════════════════════
-- Pesolita 1.7 downloads photos with the user's sign-in, so it works with a private bucket.
-- Pesolita 1.6 and older fetch them by public link: after this, restoring on those versions
-- brings the wallet back but not its photos. Run it once most users have updated.
--
-- update storage.buckets set public = false where id = 'media';
