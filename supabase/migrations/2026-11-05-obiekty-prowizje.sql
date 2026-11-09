-- Obiekty i prowizje. Można uruchomić wielokrotnie, istniejące dane zostają.
alter table public.tickets  add column if not exists properties jsonb not null default '[]'::jsonb;
alter table public.evidence add column if not exists properties jsonb not null default '[]'::jsonb;
alter table public.settings add column if not exists commission_name text;

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

