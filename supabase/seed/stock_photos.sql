-- ============================================================================
-- Stock photo backfill for the dev seed.
--
-- Populates avatar_path on the four mock seed users and photo_paths on
-- their catches with external stock-photo URLs:
--
--   Avatars   — i.pravatar.cc (consistent portrait per seed string)
--   Catches   — picsum.photos (random landscape per catch-id-derived seed)
--
-- The Flutter side accepts absolute http(s) URLs in both spots since the
-- "URL pass-through" patch landed on photo_storage / avatar_storage:
--   - SupabasePhotoStorage.signedUrl returns the URL as-is
--   - SupabaseAvatarStorage.publicUrlFor returns the URL as-is
--
-- Idempotent — re-running just refreshes the URLs (same per id).
-- Safe even if the user has uploaded a real avatar to the bucket already:
-- this script ONLY touches the four mock seed users (alice/bob/charlie/
-- jose.diaz @ fwf/bunshin), not your real Supabase Auth account.
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1. Avatars — direct JPG portraits from randomuser.me. Picked deliberately
-- because the previous pravatar.cc URLs failed to render in Flutter web
-- (they redirect through their CDN with inconsistent CORS headers).
-- randomuser.me serves direct .jpg with `Access-Control-Allow-Origin: *`.
-- ---------------------------------------------------------------------------

update public.profiles
set avatar_path = 'https://randomuser.me/api/portraits/women/68.jpg'
where id = (select id from auth.users where email = 'alice@fwf.test');

update public.profiles
set avatar_path = 'https://randomuser.me/api/portraits/men/45.jpg'
where id = (select id from auth.users where email = 'bob@fwf.test');

update public.profiles
set avatar_path = 'https://randomuser.me/api/portraits/men/22.jpg'
where id = (select id from auth.users where email = 'charlie@fwf.test');

update public.profiles
set avatar_path = 'https://randomuser.me/api/portraits/men/55.jpg'
where id = (select id from auth.users where email = 'jose.diaz@bunshin.io');

-- ---------------------------------------------------------------------------
-- 2. Catch photos — one picsum.photos URL per catch, seeded by catch id
--
-- Only touches catches owned by the four mock seed users that have no
-- photos yet. Doesn't override anything you've uploaded for real.
-- ---------------------------------------------------------------------------

update public.catches
set photo_paths = array[
  'https://picsum.photos/seed/' || substr(id::text, 1, 8) || '/800/600'
]
where angler_id in (
  select id from auth.users
  where email in (
    'alice@fwf.test',
    'bob@fwf.test',
    'charlie@fwf.test',
    'jose.diaz@bunshin.io'
  )
)
  and (photo_paths is null or array_length(photo_paths, 1) is null
       or photo_paths = '{}');

commit;

-- ---------------------------------------------------------------------------
-- Sanity output: counts that show what landed.
-- ---------------------------------------------------------------------------

select
  (select count(*) from public.profiles
     where avatar_path like 'https://%'
       and id in (
         select id from auth.users
         where email in (
           'alice@fwf.test',
           'bob@fwf.test',
           'charlie@fwf.test',
           'jose.diaz@bunshin.io'
         )
       ))                                    as mock_avatars_with_url,
  (select count(*) from public.catches
     where array_length(photo_paths, 1) > 0
       and angler_id in (
         select id from auth.users
         where email in (
           'alice@fwf.test',
           'bob@fwf.test',
           'charlie@fwf.test',
           'jose.diaz@bunshin.io'
         )
       ))                                    as mock_catches_with_photo;
