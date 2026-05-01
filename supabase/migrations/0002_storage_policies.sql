-- ============================================================================
-- Storage policies for the private "catches" bucket.
-- Run AFTER creating bucket id='catches' (public: false) in the dashboard
-- or via `supabase storage create catches --private`.
--
-- Path convention: <angler_id>/<uuid>.<ext>
-- ============================================================================

-- Owners (anglers) can fully manage their own folder.
create policy "catches_owner_full_access"
on storage.objects for all to authenticated
using (
  bucket_id = 'catches'
  and (auth.uid())::text = (storage.foldername(name))[1]
)
with check (
  bucket_id = 'catches'
  and (auth.uid())::text = (storage.foldername(name))[1]
);

-- Friends can READ each other's catch photos (used by signed-URL minting).
create policy "catches_friends_read"
on storage.objects for select to authenticated
using (
  bucket_id = 'catches'
  and public.are_friends(auth.uid(), ((storage.foldername(name))[1])::uuid)
);
