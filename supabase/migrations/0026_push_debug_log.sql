-- ============================================================================
-- 0026 — temporary push registration debug log
--
-- Without a USB cable to the iPhone we cannot read device logs. Local
-- notifications proved unreliable as a debug surface (different Dart
-- instance from the one PushMessageHandler initialized). This table
-- gives us a 100%-reliable remote log: client inserts a row at each
-- step of FCM token registration, we read the rows here in SQL editor.
--
-- Drop the table once push delivery is verified end-to-end.
-- ============================================================================

begin;

create table if not exists public.push_debug_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  msg text not null,
  created_at timestamptz not null default now()
);

create index if not exists push_debug_log_user_idx
  on public.push_debug_log (user_id, created_at desc);

alter table public.push_debug_log enable row level security;

drop policy if exists push_debug_log_select_own on public.push_debug_log;
create policy push_debug_log_select_own on public.push_debug_log
  for select to authenticated using (user_id = auth.uid());

drop policy if exists push_debug_log_insert_own on public.push_debug_log;
create policy push_debug_log_insert_own on public.push_debug_log
  for insert to authenticated with check (user_id = auth.uid());

notify pgrst, 'reload schema';

commit;
