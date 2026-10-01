-- WealthPilot / Ship-a-ton Supabase schema
-- Safe to run in a fresh project. Existing tables receive the columns added below.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  age integer,
  onboarding_complete boolean not null default false,
  monthly_budget numeric(12,2) not null default 0,
  savings_balance numeric(12,2) not null default 0,
  savings_goal numeric(12,2) not null default 0,
  theme_mode text not null default 'system' check (theme_mode in ('system','light','dark')),
  trial_started_at timestamptz not null default now(),
  trial_ends_at timestamptz not null default (now() + interval '6 days'),
  subscription_status text not null default 'trial',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles add column if not exists display_name text not null default '';
alter table public.profiles add column if not exists age integer;
alter table public.profiles add column if not exists onboarding_complete boolean not null default false;

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  merchant text not null,
  category text not null,
  amount numeric(12,2) not null check (amount >= 0),
  type text not null check (type in ('income','expense')),
  source text not null default 'manual',
  source_fingerprint text,
  source_balance numeric(14,2),
  source_occurrence integer not null default 1,
  created_at timestamptz not null default now()
);

alter table public.transactions add column if not exists source text not null default 'manual';
alter table public.transactions add column if not exists source_fingerprint text;
alter table public.transactions add column if not exists source_balance numeric(14,2);
alter table public.transactions add column if not exists source_occurrence integer not null default 1;

create index if not exists transactions_user_date_idx
  on public.transactions(user_id, date desc);
drop index if exists public.transactions_user_fingerprint_idx;
create unique index transactions_user_fingerprint_idx
  on public.transactions(user_id, source_fingerprint);

create table if not exists public.statement_imports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  transaction_count integer not null default 0,
  extracted_transaction_count integer not null default 0,
  saved_transaction_count integer not null default 0,
  duplicate_transaction_count integer not null default 0,
  first_transaction_date date,
  last_transaction_date date,
  created_at timestamptz not null default now()
);

alter table public.statement_imports add column if not exists extracted_transaction_count integer not null default 0;
alter table public.statement_imports add column if not exists saved_transaction_count integer not null default 0;
alter table public.statement_imports add column if not exists duplicate_transaction_count integer not null default 0;

create index if not exists statement_imports_user_created_idx
  on public.statement_imports(user_id, created_at desc);

create table if not exists public.upcoming_bills (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  due_date date not null,
  merchant text not null,
  category text not null default 'Utilities',
  amount numeric(12,2) not null check (amount >= 0),
  created_at timestamptz not null default now()
);

create index if not exists upcoming_bills_user_date_idx
  on public.upcoming_bills(user_id, due_date asc);

create table if not exists public.financial_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  goal_type text not null default 'savings',
  target_amount numeric(12,2) not null check (target_amount >= 0),
  target_date date,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.transactions enable row level security;
alter table public.statement_imports enable row level security;
alter table public.upcoming_bills enable row level security;
alter table public.financial_goals enable row level security;

-- Recreate policies so rerunning this file does not fail.
drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
drop policy if exists "transactions_select_own" on public.transactions;
drop policy if exists "transactions_insert_own" on public.transactions;
drop policy if exists "transactions_update_own" on public.transactions;
drop policy if exists "transactions_delete_own" on public.transactions;
drop policy if exists "statement_imports_select_own" on public.statement_imports;
drop policy if exists "statement_imports_insert_own" on public.statement_imports;
drop policy if exists "bills_select_own" on public.upcoming_bills;
drop policy if exists "bills_insert_own" on public.upcoming_bills;
drop policy if exists "bills_update_own" on public.upcoming_bills;
drop policy if exists "bills_delete_own" on public.upcoming_bills;
drop policy if exists "goals_select_own" on public.financial_goals;
drop policy if exists "goals_insert_own" on public.financial_goals;
drop policy if exists "goals_update_own" on public.financial_goals;
drop policy if exists "goals_delete_own" on public.financial_goals;

create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = user_id);
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = user_id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "transactions_select_own" on public.transactions
  for select using (auth.uid() = user_id);
create policy "transactions_insert_own" on public.transactions
  for insert with check (auth.uid() = user_id);
create policy "transactions_update_own" on public.transactions
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "transactions_delete_own" on public.transactions
  for delete using (auth.uid() = user_id);

create policy "statement_imports_select_own" on public.statement_imports
  for select using (auth.uid() = user_id);
create policy "statement_imports_insert_own" on public.statement_imports
  for insert with check (auth.uid() = user_id);

create policy "bills_select_own" on public.upcoming_bills
  for select using (auth.uid() = user_id);
create policy "bills_insert_own" on public.upcoming_bills
  for insert with check (auth.uid() = user_id);
create policy "bills_update_own" on public.upcoming_bills
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "bills_delete_own" on public.upcoming_bills
  for delete using (auth.uid() = user_id);

create policy "goals_select_own" on public.financial_goals
  for select using (auth.uid() = user_id);
create policy "goals_insert_own" on public.financial_goals
  for insert with check (auth.uid() = user_id);
create policy "goals_update_own" on public.financial_goals
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "goals_delete_own" on public.financial_goals
  for delete using (auth.uid() = user_id);

-- Create a private profile and begin the 6-day trial at sign-up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();
