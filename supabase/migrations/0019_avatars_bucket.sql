-- ============================================================================
-- 0019 — public avatars storage bucket + policies
--
-- M7 lets users pick a profile avatar during onboarding or via edit
-- profile. Storing avatars in the existing private `catches` bucket
-- would require signing URLs every time a friend's avatar renders in
-- a list — heavy. Avatars aren't sensitive (they're already trivially
-- inferable from the username), so we ship a separate public bucket
-- and gate writes by user-id-prefixed path.
--
-- Path convention: `<user_id>/<timestamp>.<ext>`
--
-- The owner-folder check (`storage.foldername(name))[1] = auth.uid()::text`)
-- mirrors the catches bucket policy from 0002.
-- ============================================================================

begin;

-- Create the bucket (idempotent).
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

-- Public read — any authenticated or anon user can fetch any avatar URL.
drop policy if exists avatars_public_select on storage.objects;
create policy avatars_public_select
  on storage.objects for select
  using (bucket_id = 'avatars');

-- Owner-only writes — angler can only write to their own user-id folder.
drop policy if exists avatars_owner_insert on storage.objects;
create policy avatars_owner_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists avatars_owner_update on storage.objects;
create policy avatars_owner_update
  on storage.objects for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists avatars_owner_delete on storage.objects;
create policy avatars_owner_delete
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

commit;
