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
