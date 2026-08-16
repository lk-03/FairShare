-- FairShare Database Schema for Supabase (PostgreSQL + RLS)
-- Author: Kowsic L (24BPS1100)

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- 1. Profiles Table
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  full_name text not null,
  avatar_url text,
  vpa_id text, -- Payee UPI VPA (e.g. user@okaxis)
  phone_number text,
  is_guest boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Event Cohorts Table
create table public.event_cohorts (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  description text,
  category text not null check (category in ('trip', 'house', 'event', 'dining', 'other')),
  banner_url text,
  currency text default 'INR' not null,
  invite_code text unique not null,
  created_by uuid references public.profiles(id) on delete cascade not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. Group Members Table
create table public.group_members (
  id uuid default uuid_generate_v4() primary key,
  cohort_id uuid references public.event_cohorts(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  role text default 'member' check (role in ('admin', 'member')),
  joined_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (cohort_id, user_id)
);

-- 4. Expenses Table
create table public.expenses (
  id uuid default uuid_generate_v4() primary key,
  cohort_id uuid references public.event_cohorts(id) on delete cascade not null,
  title text not null,
  category text default 'General',
  total_amount numeric(12, 2) not null check (total_amount > 0),
  currency text default 'INR' not null,
  paid_by_user_id uuid references public.profiles(id) on delete cascade not null,
  split_type text default 'equal' check (split_type in ('equal', 'exact', 'percentage', 'itemized')),
  receipt_url text,
  ocr_parsed boolean default false,
  notes text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 5. Expense Line Items (for OCR and itemized splits)
create table public.expense_line_items (
  id uuid default uuid_generate_v4() primary key,
  expense_id uuid references public.expenses(id) on delete cascade not null,
  title text not null,
  price numeric(12, 2) not null,
  quantity integer default 1 not null
);

-- 6. Expense Splits Table
create table public.expense_splits (
  id uuid default uuid_generate_v4() primary key,
  expense_id uuid references public.expenses(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  amount numeric(12, 2) not null,
  percentage numeric(5, 2),
  unique (expense_id, user_id)
);

-- 7. Transaction Comments Table
create table public.transaction_comments (
  id uuid default uuid_generate_v4() primary key,
  expense_id uuid references public.expenses(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  content text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Row Level Security (RLS) Policies
alter table public.profiles enable row level security;
alter table public.event_cohorts enable row level security;
alter table public.group_members enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_line_items enable row level security;
alter table public.expense_splits enable row level security;
alter table public.transaction_comments enable row level security;

-- Profile Access Policy
create policy "Users can view all public profiles"
  on public.profiles for select
  using (true);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- Event Cohort Access Policy: Users can view cohorts they are members of
create policy "Members can view their event cohorts"
  on public.event_cohorts for select
  using (
    exists (
      select 1 from public.group_members gm
      where gm.cohort_id = public.event_cohorts.id
      and gm.user_id = auth.uid()
    )
  );

create policy "Users can create event cohorts"
  on public.event_cohorts for insert
  with check (auth.uid() = created_by);

-- Expenses Policy
create policy "Members can view cohort expenses"
  on public.expenses for select
  using (
    exists (
      select 1 from public.group_members gm
      where gm.cohort_id = public.expenses.cohort_id
      and gm.user_id = auth.uid()
    )
  );

create policy "Members can insert cohort expenses"
  on public.expenses for insert
  with check (
    exists (
      select 1 from public.group_members gm
      where gm.cohort_id = public.expenses.cohort_id
      and gm.user_id = auth.uid()
    )
  );
