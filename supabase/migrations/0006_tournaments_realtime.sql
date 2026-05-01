-- ============================================================================
-- 0006 — tournaments realtime: snapshot entries, chat, side pots, triggers
--
-- Extends the M0 tournaments tables with what M3 needs to run a live
-- competition end-to-end:
--   * tournaments.join_code   — share-anywhere 8-char hex code
--   * tournaments.is_closed   — creator-toggleable early-close flag
--   * tournament_entries: snapshot fields (species, weight, length,
--     photo_path, caught_at) + status enum so non-friend fellows can read
--     the leaderboard without weakening catches RLS
--   * tournament_side_pots    — per-tournament side-board configs
--   * tournament_chat_messages — flat soft-deletable chat
--   * 5 new notification_kind values (tournament_*)
--   * 3 trigger functions writing notifications on member/entry resolution
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- tournaments — join_code + is_closed
-- ----------------------------------------------------------------------------

alter table public.tournaments
  add column if not exists join_code text not null
    default lpad(to_hex((random() * 4294967295)::bigint), 8, '0'),
  add column if not exists is_closed boolean not null default false;

create unique index if not exists tournaments_join_code_idx
  on public.tournaments (join_code);

-- ----------------------------------------------------------------------------
-- tournament_entries — snapshot fields + status
-- ----------------------------------------------------------------------------

alter table public.tournament_entries
  add column if not exists species_label text,
  add column if not exists weight_kg numeric(6, 2),
  add column if not exists length_cm numeric(6, 2),
  add column if not exists photo_path text,
  add column if not exists caught_at timestamptz,
  add column if not exists status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected'));

create index if not exists tournament_entries_status_idx
  on public.tournament_entries (tournament_id, status);

-- ----------------------------------------------------------------------------
-- tournament_side_pots — per-tournament side leaderboards
-- ----------------------------------------------------------------------------

create table if not exists public.tournament_side_pots (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null
    references public.tournaments(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  metric public.tournament_metric not null,
  species_filter text,
  created_at timestamptz not null default now()
);

create index if not exists tournament_side_pots_tournament_idx
  on public.tournament_side_pots (tournament_id);

-- ----------------------------------------------------------------------------
-- tournament_chat_messages — members-only chat thread
-- ----------------------------------------------------------------------------

create table if not exists public.tournament_chat_messages (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null
    references public.tournaments(id) on delete cascade,
  author_id uuid not null
    references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists tournament_chat_messages_tournament_idx
  on public.tournament_chat_messages (tournament_id, created_at);

-- updated_at trigger reuses the helper from 0001_init.sql.
do $$
declare t text;
begin
  for t in select unnest(array['tournament_chat_messages']) loop
    execute format('drop trigger if exists set_updated_at on public.%I', t);
    execute format(
      'create trigger set_updated_at before update on public.%I
       for each row execute function public.tg_set_updated_at()', t
    );
  end loop;
end$$;

-- ============================================================================
-- RLS — side pots + chat
-- ============================================================================

alter table public.tournament_side_pots enable row level security;
alter table public.tournament_chat_messages enable row level security;

-- Side pots: visible to creator + accepted members; only creator manages.
create policy side_pots_select on public.tournament_side_pots
  for select to authenticated using (
    exists (
      select 1 from public.tournaments t
      where t.id = tournament_side_pots.tournament_id
        and (
          t.creator_id = auth.uid()
          or exists (
            select 1 from public.tournament_members m
            where m.tournament_id = t.id
              and m.angler_id = auth.uid()
              and m.status = 'accepted'
          )
        )
    )
  );

create policy side_pots_creator_write on public.tournament_side_pots
  for all to authenticated
  using (
    exists (
      select 1 from public.tournaments t
      where t.id = tournament_side_pots.tournament_id
        and t.creator_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.tournaments t
      where t.id = tournament_side_pots.tournament_id
        and t.creator_id = auth.uid()
    )
  );

-- Chat: visible to creator + accepted members. Author writes. Author can only
-- update `deleted_at` (soft-delete) — no body edits in v1.
create policy chat_select_member on public.tournament_chat_messages
  for select to authenticated using (
    exists (
      select 1 from public.tournaments t
      where t.id = tournament_chat_messages.tournament_id
        and (
          t.creator_id = auth.uid()
          or exists (
            select 1 from public.tournament_members m
            where m.tournament_id = t.id
              and m.angler_id = auth.uid()
              and m.status = 'accepted'
          )
        )
    )
  );

create policy chat_insert_member on public.tournament_chat_messages
  for insert to authenticated with check (
    author_id = auth.uid()
    and exists (
      select 1 from public.tournaments t
      where t.id = tournament_chat_messages.tournament_id
        and (
          t.creator_id = auth.uid()
          or exists (
            select 1 from public.tournament_members m
            where m.tournament_id = t.id
              and m.angler_id = auth.uid()
              and m.status = 'accepted'
          )
        )
    )
  );

create policy chat_soft_delete_author on public.tournament_chat_messages
  for update to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid());

-- ============================================================================
-- Notification kinds + triggers
-- ============================================================================

do $$
begin
  if not exists (
    select 1 from pg_type t
    join pg_enum e on t.oid = e.enumtypid
    where t.typname = 'notification_kind' and e.enumlabel = 'tournament_invite'
  ) then
    alter type public.notification_kind add value 'tournament_invite';
  end if;
  if not exists (
    select 1 from pg_type t
    join pg_enum e on t.oid = e.enumtypid
    where t.typname = 'notification_kind' and e.enumlabel = 'tournament_member_approved'
  ) then
    alter type public.notification_kind add value 'tournament_member_approved';
  end if;
  if not exists (
    select 1 from pg_type t
    join pg_enum e on t.oid = e.enumtypid
    where t.typname = 'notification_kind' and e.enumlabel = 'tournament_member_rejected'
  ) then
    alter type public.notification_kind add value 'tournament_member_rejected';
  end if;
  if not exists (
    select 1 from pg_type t
    join pg_enum e on t.oid = e.enumtypid
    where t.typname = 'notification_kind' and e.enumlabel = 'tournament_entry_approved'
  ) then
    alter type public.notification_kind add value 'tournament_entry_approved';
  end if;
  if not exists (
    select 1 from pg_type t
    join pg_enum e on t.oid = e.enumtypid
    where t.typname = 'notification_kind' and e.enumlabel = 'tournament_entry_rejected'
  ) then
    alter type public.notification_kind add value 'tournament_entry_rejected';
  end if;
end$$;

create or replace function public.tg_notify_tournament_invite() returns trigger
language plpgsql security definer as $$
begin
  if new.status = 'pending' then
    insert into public.notifications (recipient_id, kind, payload)
    values (
      new.angler_id,
      'tournament_invite'::public.notification_kind,
      jsonb_build_object('tournament_id', new.tournament_id)
    );
  end if;
  return new;
end;
$$;

create or replace function public.tg_notify_tournament_member_resolved() returns trigger
language plpgsql security definer as $$
begin
  if old.status = 'pending' and new.status in ('accepted', 'rejected')
     and new.angler_id <> coalesce(new.approved_by, '00000000-0000-0000-0000-000000000000'::uuid)
  then
    insert into public.notifications (recipient_id, kind, payload)
    values (
      new.angler_id,
      case new.status
        when 'accepted' then 'tournament_member_approved'::public.notification_kind
        else 'tournament_member_rejected'::public.notification_kind
      end,
      jsonb_build_object('tournament_id', new.tournament_id)
    );
  end if;
  return new;
end;
$$;

create or replace function public.tg_notify_tournament_entry_resolved() returns trigger
language plpgsql security definer as $$
declare actor uuid;
begin
  if old.status = 'pending' and new.status in ('approved', 'rejected') then
    actor := coalesce(new.approved_by, '00000000-0000-0000-0000-000000000000'::uuid);
    if new.angler_id <> actor then
      insert into public.notifications (recipient_id, kind, payload)
      values (
        new.angler_id,
        case new.status
          when 'approved' then 'tournament_entry_approved'::public.notification_kind
          else 'tournament_entry_rejected'::public.notification_kind
        end,
        jsonb_build_object(
          'tournament_id', new.tournament_id,
          'entry_id', new.id
        )
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists notify_tournament_invite on public.tournament_members;
create trigger notify_tournament_invite
  after insert on public.tournament_members
  for each row execute function public.tg_notify_tournament_invite();

drop trigger if exists notify_tournament_member_resolved on public.tournament_members;
create trigger notify_tournament_member_resolved
  after update on public.tournament_members
  for each row execute function public.tg_notify_tournament_member_resolved();

drop trigger if exists notify_tournament_entry_resolved on public.tournament_entries;
create trigger notify_tournament_entry_resolved
  after update on public.tournament_entries
  for each row execute function public.tg_notify_tournament_entry_resolved();

commit;
