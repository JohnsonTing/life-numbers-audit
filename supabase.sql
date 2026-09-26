-- Run once in Supabase: SQL Editor -> New query -> paste -> Run

create table if not exists time_entries (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  activity int not null,
  start_ts timestamptz not null,
  end_ts timestamptz,
  deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists counts (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  funnel text not null,
  stage text not null,
  ts timestamptz not null,
  deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table time_entries enable row level security;
alter table counts enable row level security;

create policy "own time_entries" on time_entries for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own counts" on counts for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Server-side sync timestamp: lets clients pull only rows changed since their last sync.
-- Set by the database (not the device clock) so offline edits synced later are never missed.
alter table time_entries add column if not exists synced_at timestamptz not null default now();
alter table counts add column if not exists synced_at timestamptz not null default now();

create or replace function set_synced_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.synced_at = now();
  return new;
end $$;

drop trigger if exists time_entries_synced_at on time_entries;
create trigger time_entries_synced_at before insert or update on time_entries
  for each row execute function set_synced_at();
drop trigger if exists counts_synced_at on counts;
create trigger counts_synced_at before insert or update on counts
  for each row execute function set_synced_at();

create index if not exists time_entries_user_synced on time_entries (user_id, synced_at);
create index if not exists counts_user_synced on counts (user_id, synced_at);

-- Per-user activity categories. `key` matches time_entries.activity.
-- Defaults use keys 0..12 (the original fixed list); new ones get random keys so devices never collide.
create table if not exists categories (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  key int not null,
  name text not null,
  color text not null,
  sort int not null default 0,
  deleted boolean not null default false,
  updated_at timestamptz not null default now(),
  synced_at timestamptz not null default now(),
  primary key (user_id, key)
);
alter table categories enable row level security;
create policy "own categories" on categories for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop trigger if exists categories_synced_at on categories;
create trigger categories_synced_at before insert or update on categories
  for each row execute function set_synced_at();
create index if not exists categories_user_synced on categories (user_id, synced_at);

-- Per-user tap counters on the Calls tab. `key` matches counts.stage; kind 'step' = funnel step, 'tally' = plain count.
create table if not exists counters (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  funnel text not null,
  key text not null,
  name text not null,
  kind text not null default 'tally' check (kind in ('step','tally')),
  sort int not null default 0,
  deleted boolean not null default false,
  updated_at timestamptz not null default now(),
  synced_at timestamptz not null default now(),
  primary key (user_id, funnel, key)
);
alter table counters enable row level security;
create policy "own counters" on counters for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop trigger if exists counters_synced_at on counters;
create trigger counters_synced_at before insert or update on counters
  for each row execute function set_synced_at();
create index if not exists counters_user_synced on counters (user_id, synced_at);
