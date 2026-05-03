-- ============================================================================
-- 0017 — push notifications schema
--
-- M6c introduces FCM-based push delivery. Two new tables:
--
--   device_tokens         — one row per (user, device) pair holding the FCM
--                           registration token. Owner-only insert/update/
--                           delete; service role reads to dispatch.
--   notification_preferences — per-user category toggles (friend requests,
--                           tournaments, feed). Owner-only RLS.
--
-- The dispatch trigger lives in 0018 so this migration is purely schema +
-- RLS. Run 0017 + 0018 in order.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- device_tokens
-- ----------------------------------------------------------------------------
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('ios', 'android', 'web')),
  last_seen_at timestamptz not null default now(),
  unique (user_id, token)
);

create index if not exists device_tokens_user_idx
  on public.device_tokens (user_id, last_seen_at desc);

alter table public.device_tokens enable row level security;

drop policy if exists device_tokens_owner_insert on public.device_tokens;
create policy device_tokens_owner_insert on public.device_tokens
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists device_tokens_owner_update on public.device_tokens;
create policy device_tokens_owner_update on public.device_tokens
  for update to authenticated using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists device_tokens_owner_delete on public.device_tokens;
create policy device_tokens_owner_delete on public.device_tokens
  for delete to authenticated using (user_id = auth.uid());

-- No SELECT policy — only the service role (which the edge function uses)
-- can read tokens, and bypasses RLS.

-- ----------------------------------------------------------------------------
-- notification_preferences
-- ----------------------------------------------------------------------------
create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  friend_requests boolean not null default true,
  tournaments boolean not null default true,
  feed boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;

drop policy if exists notification_preferences_owner_select
  on public.notification_preferences;
create policy notification_preferences_owner_select
  on public.notification_preferences
  for select to authenticated using (user_id = auth.uid());

drop policy if exists notification_preferences_owner_upsert
  on public.notification_preferences;
create policy notification_preferences_owner_upsert
  on public.notification_preferences
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists notification_preferences_owner_update
  on public.notification_preferences;
create policy notification_preferences_owner_update
  on public.notification_preferences
  for update to authenticated using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- Helper — service-role-only read used by the dispatch edge function.
-- Defined as a security-definer function so the edge function can stay
-- focused on FCM logic without hand-rolling auth.
-- ----------------------------------------------------------------------------
create or replace function public.fwf_lookup_push_recipients(
  p_user_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_prefs record;
  v_tokens jsonb;
begin
  select friend_requests, tournaments, feed
    into v_prefs
    from public.notification_preferences
    where user_id = p_user_id;

  -- Default-on when no preferences row exists yet.
  if v_prefs is null then
    v_prefs := row(true, true, true);
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'token', token,
           'platform', platform
         )), '[]'::jsonb)
    into v_tokens
    from public.device_tokens
    where user_id = p_user_id;

  return jsonb_build_object(
    'tokens', v_tokens,
    'prefs', jsonb_build_object(
      'friend_requests', v_prefs.friend_requests,
      'tournaments', v_prefs.tournaments,
      'feed', v_prefs.feed
    )
  );
end;
$$;

notify pgrst, 'reload schema';

commit;
