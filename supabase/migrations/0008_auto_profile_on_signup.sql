-- ============================================================================
-- 0008 — auto-create profiles on sign-up + backfill existing users
--
-- The 0001 schema kept `auth.users` and `public.profiles` separate but
-- never wired a trigger to mirror new auth users into profiles. Foreign
-- keys throughout the app (catches.angler_id, tournaments.creator_id,
-- friendships.requester_id, etc.) point to profiles, so any insert from
-- a freshly-signed-up user fails with a FK violation.
--
-- Fix: a trigger on auth.users INSERT that auto-creates a profile row
-- with a derived username (email local-part, sanitized + uniquified).
-- Plus a one-time backfill for users who signed up before this migration.
-- ============================================================================

begin;

create or replace function public.derive_username(p_user_id uuid, p_email text)
returns text
language plpgsql
stable
as $$
declare
  base_username text;
  candidate text;
  suffix int := 0;
begin
  -- Strip everything that isn't alphanumeric or underscore from the email
  -- local-part. Profiles CHECK requires 3..30 chars; pad with random suffix
  -- when needed.
  base_username := lower(
    regexp_replace(split_part(coalesce(p_email, ''), '@', 1), '[^a-zA-Z0-9_]', '', 'g')
  );
  if char_length(base_username) < 3 then
    base_username := 'angler' || substr(replace(p_user_id::text, '-', ''), 1, 6);
  end if;
  candidate := substr(base_username, 1, 30);

  -- Uniquify by appending a numeric suffix.
  while exists (select 1 from public.profiles where username = candidate) loop
    suffix := suffix + 1;
    candidate := substr(base_username, 1, 30 - char_length(suffix::text)) || suffix::text;
  end loop;

  return candidate;
end;
$$;

create or replace function public.tg_create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (new.id, public.derive_username(new.id, new.email))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists create_profile_for_new_user on auth.users;
create trigger create_profile_for_new_user
  after insert on auth.users
  for each row execute function public.tg_create_profile_for_new_user();

-- ----------------------------------------------------------------------------
-- One-time backfill — every auth.users row missing a profile gets one
-- ----------------------------------------------------------------------------

do $$
declare u record;
begin
  for u in
    select au.id, au.email
    from auth.users au
    where not exists (
      select 1 from public.profiles p where p.id = au.id
    )
  loop
    insert into public.profiles (id, username)
    values (u.id, public.derive_username(u.id, u.email))
    on conflict (id) do nothing;
  end loop;
end$$;

-- Refresh PostgREST schema cache.
notify pgrst, 'reload schema';

commit;
