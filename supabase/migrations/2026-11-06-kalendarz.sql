-- Rodzaj wpisu (usterka / notatka) i data w kalendarzu. Można uruchomić wielokrotnie, dane zostają.
alter table public.tickets add column if not exists kind text not null default 'usterka';
alter table public.tickets add column if not exists due_date date;
