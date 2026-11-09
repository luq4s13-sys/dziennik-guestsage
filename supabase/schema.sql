-- =====================================================================
-- Dziennik GuestSage — schemat bazy dla Supabase
-- Uruchom RAZ: Supabase → SQL Editor → New query → wklej całość → Run.
-- Można uruchomić ponownie bez utraty danych.
-- =====================================================================

-- ---------- Tabele ----------
create table if not exists public.tickets (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  num         integer not null,
  title       text not null,
  company     text not null default 'GP' check (company in ('GP','GG','ALL')),
  module      text,
  priority    text not null default 'sredni',
  sent_at     date not null default current_date,
  channel     text,
  gs_ref      text,
  status      text not null default 'wyslane',
  description text,
  impact      text,
  events      jsonb not null default '[]'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.journal (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date       date not null default current_date,
  company    text not null default 'GP' check (company in ('GP','GG','ALL')),
  text       text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.evidence (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title       text not null,
  date        date not null default current_date,
  company     text not null default 'GP' check (company in ('GP','GG','ALL')),
  ticket_id   uuid references public.tickets(id) on delete set null,
  description text,
  files       jsonb not null default '[]'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.settings (
  user_id    uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  threshold  integer not null default 3,
  stale_days integer not null default 7
);

create index if not exists tickets_user_idx  on public.tickets(user_id);
create index if not exists journal_user_idx  on public.journal(user_id, date);
create index if not exists evidence_user_idx on public.evidence(user_id);
create index if not exists evidence_ticket_idx on public.evidence(ticket_id);

-- ---------- Dostęp: każdy widzi i zmienia tylko swoje dane ----------
alter table public.tickets  enable row level security;
alter table public.journal  enable row level security;
alter table public.evidence enable row level security;
alter table public.settings enable row level security;

drop policy if exists "own rows" on public.tickets;
drop policy if exists "own rows" on public.journal;
drop policy if exists "own rows" on public.evidence;
drop policy if exists "own rows" on public.settings;

create policy "own rows" on public.tickets  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own rows" on public.journal  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own rows" on public.evidence for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own rows" on public.settings for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

revoke all on public.tickets, public.journal, public.evidence, public.settings from anon;
grant select, insert, update, delete on public.tickets, public.journal, public.evidence, public.settings to authenticated;

-- ---------- Pliki (dowody): prywatny schowek, max 50 MB na plik ----------
insert into storage.buckets (id, name, public, file_size_limit)
values ('dowody', 'dowody', false, 52428800)
on conflict (id) do update set public = false, file_size_limit = 52428800;

drop policy if exists "dowody read own"   on storage.objects;
drop policy if exists "dowody insert own" on storage.objects;
drop policy if exists "dowody update own" on storage.objects;
drop policy if exists "dowody delete own" on storage.objects;

create policy "dowody read own" on storage.objects for select to authenticated
  using (bucket_id = 'dowody' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "dowody insert own" on storage.objects for insert to authenticated
  with check (bucket_id = 'dowody' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "dowody update own" on storage.objects for update to authenticated
  using (bucket_id = 'dowody' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "dowody delete own" on storage.objects for delete to authenticated
  using (bucket_id = 'dowody' and (storage.foldername(name))[1] = auth.uid()::text);

-- ---------- Zdjęcie na ekranie logowania (prywatne, tylko właściciel konta) ----------
alter table public.settings add column if not exists login_photo text;
alter table public.settings drop constraint if exists settings_login_photo_size;
alter table public.settings add constraint settings_login_photo_size check (login_photo is null or length(login_photo) < 400000);

-- ---------- Obiekty, których dotyczy zgłoszenie lub dowód ----------
alter table public.tickets  add column if not exists properties jsonb not null default '[]'::jsonb;
alter table public.evidence add column if not exists properties jsonb not null default '[]'::jsonb;

-- ---------- Prowizje ----------
create table if not exists public.commissions (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users(id) on delete cascade,
  reservation_id text not null,
  stay_from      date not null,
  stay_to        date not null,
  price          numeric(12,2) not null,
  rate           numeric(5,2) not null default 2,
  amount         numeric(12,2) not null,
  property       text,
  created_at     timestamptz not null default now()
);
create index if not exists commissions_user_idx on public.commissions(user_id, stay_from);
alter table public.commissions enable row level security;
drop policy if exists "own rows" on public.commissions;
create policy "own rows" on public.commissions for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
revoke all on public.commissions from anon;
grant select, insert, update, delete on public.commissions to authenticated;
alter table public.settings add column if not exists commission_name text;

-- ---------- Rodzaj wpisu i data w kalendarzu ----------
alter table public.tickets add column if not exists kind text not null default 'usterka';
alter table public.tickets add column if not exists due_date date;
