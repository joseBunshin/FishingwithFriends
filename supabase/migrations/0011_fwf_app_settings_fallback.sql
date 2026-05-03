-- ============================================================================
-- 0011 — fwf_app_settings table-backed config (no-superuser fallback)
--
-- The Supabase dashboard SQL Editor runs as a non-superuser role, so
-- `alter database postgres set "app.settings.foo" = ...` fails with:
--   42501: permission denied to set parameter ...
--
-- Workaround: store the same key/value pairs in a regular table with RLS
-- deny-all, then have `fwf_setting()` read from the table (still as a
-- security-definer function so it bypasses RLS). Existing GUC-based
-- config keeps working when superuser is available — the table is only
-- consulted as a fallback.
-- ============================================================================

begin;

create table if not exists public.fwf_app_settings (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);

alter table public.fwf_app_settings enable row level security;
-- No SELECT/INSERT/UPDATE/DELETE policies — clients cannot read or write
-- this table. Only security-definer functions (running as the table
-- owner) reach it.

create or replace function public.fwf_setting(p_name text)
returns text
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v text;
begin
  -- Try the GUC first (set via `alter database postgres set ...`).
  -- This path works when superuser is available.
  v := nullif(current_setting(p_name, true), '');
  if v is not null then
    return v;
  end if;

  -- Fall back to the settings table (no superuser required).
  select value into v
    from public.fwf_app_settings
    where key = p_name;
  return v;
end;
$$;

notify pgrst, 'reload schema';

commit;
