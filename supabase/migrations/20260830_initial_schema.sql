-- ============================================================================
-- FAIRSHARE SUPABASE DATABASE SCHEMA MIGRATION
-- ============================================================================
-- Complete PostgreSQL schema for FairShare including profiles, event cohorts,
-- group members, expenses, multi-mode splits, line items, comments,
-- shared house cart needs, shortcuts, Row Level Security (RLS), and Storage.
-- ============================================================================

-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. PROFILES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    full_name TEXT NOT NULL,
    nickname TEXT,
    username TEXT UNIQUE,
    avatar_url TEXT,
    vpa_id TEXT, -- UPI ID (e.g. name@okaxis)
    phone_number TEXT,
    is_guest BOOLEAN DEFAULT false,
    auth_provider TEXT DEFAULT 'email',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for username lookups and mentions
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);

-- ============================================================================
-- 2. EVENT COHORTS (GROUPS) TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.cohorts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL DEFAULT 'house',
    custom_icon TEXT,
    avatar_url TEXT,
    banner_url TEXT,
    currency TEXT NOT NULL DEFAULT 'INR',
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    invite_code TEXT UNIQUE NOT NULL,
    is_archived BOOLEAN DEFAULT false,
    archived_at TIMESTAMPTZ,
    is_deleted BOOLEAN DEFAULT false,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for invite code lookups
CREATE INDEX IF NOT EXISTS idx_cohorts_invite_code ON public.cohorts(invite_code);
CREATE INDEX IF NOT EXISTS idx_cohorts_created_by ON public.cohorts(created_by);

-- ============================================================================
-- 3. GROUP MEMBERS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cohort_id UUID NOT NULL REFERENCES public.cohorts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member', -- 'admin' | 'member'
    is_placeholder BOOLEAN DEFAULT false,
    original_csv_name TEXT,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_cohort_user UNIQUE(cohort_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_members_cohort ON public.group_members(cohort_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user ON public.group_members(user_id);

-- ============================================================================
-- 4. EXPENSES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cohort_id UUID NOT NULL REFERENCES public.cohorts(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'general',
    custom_icon TEXT,
    total_amount NUMERIC(12, 2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'INR',
    paid_by_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    split_type TEXT NOT NULL DEFAULT 'equal', -- 'equal' | 'exact' | 'percentage' | 'shares' | 'adjustment' | 'itemized'
    subtotal NUMERIC(12, 2),
    tax_amount NUMERIC(12, 2) DEFAULT 0,
    service_charge NUMERIC(12, 2) DEFAULT 0,
    discount_amount NUMERIC(12, 2) DEFAULT 0,
    receipt_url TEXT,
    ocr_parsed BOOLEAN DEFAULT false,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_expenses_cohort_created ON public.expenses(cohort_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_expenses_paid_by ON public.expenses(paid_by_user_id);

-- ============================================================================
-- 5. EXPENSE SPLITS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.expense_splits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_id UUID NOT NULL REFERENCES public.expenses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount NUMERIC(12, 2) NOT NULL,
    percentage NUMERIC(6, 2),
    line_item_ids TEXT[],
    CONSTRAINT uq_expense_user UNIQUE(expense_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_expense_splits_expense ON public.expense_splits(expense_id);
CREATE INDEX IF NOT EXISTS idx_expense_splits_user ON public.expense_splits(user_id);

-- ============================================================================
-- 6. LINE ITEMS (ITEMIZED RECEIPTS) TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.line_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_id UUID NOT NULL REFERENCES public.expenses(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    price NUMERIC(12, 2) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    split_type TEXT NOT NULL DEFAULT 'equal',
    assigned_user_ids UUID[] NOT NULL DEFAULT '{}',
    sort_order INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_line_items_expense ON public.line_items(expense_id);

-- ============================================================================
-- 7. LINE ITEM ASSIGNMENTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.line_item_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    line_item_id UUID NOT NULL REFERENCES public.line_items(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    split_type TEXT DEFAULT 'equal',
    value NUMERIC(12, 2) DEFAULT 1,
    calculated_amount NUMERIC(12, 2) NOT NULL,
    CONSTRAINT uq_line_item_user UNIQUE(line_item_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_line_item_assignments_item ON public.line_item_assignments(line_item_id);

-- ============================================================================
-- 8. TRANSACTION COMMENTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_id UUID NOT NULL REFERENCES public.expenses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comments_expense_created ON public.comments(expense_id, created_at ASC);

-- ============================================================================
-- 9. SHARED LIST ITEMS (HOUSE CART / NEEDS) TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.shared_list_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cohort_id UUID NOT NULL REFERENCES public.cohorts(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    added_by_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    is_completed BOOLEAN DEFAULT false,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_shared_list_cohort ON public.shared_list_items(cohort_id, created_at DESC);

-- ============================================================================
-- 10. EXPENSE SHORTCUTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.expense_shortcuts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cohort_id UUID NOT NULL REFERENCES public.cohorts(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'general',
    custom_icon TEXT,
    amount NUMERIC(12, 2) NOT NULL,
    paid_by_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    split_type TEXT NOT NULL DEFAULT 'equal',
    split_payload JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_expense_shortcuts_cohort ON public.expense_shortcuts(cohort_id);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cohorts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_splits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.line_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.line_item_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shared_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_shortcuts ENABLE ROW LEVEL SECURITY;

-- Helper function: Check if current authenticated user is a member of a cohort
CREATE OR REPLACE FUNCTION public.is_member_of_cohort(cohort_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.group_members
        WHERE group_members.cohort_id = $1
        AND group_members.user_id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to automatically create a public.profiles row when a new user signs up via Google or Email
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, avatar_url, auth_provider)
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1), 'User'),
    COALESCE(new.raw_user_meta_data->>'avatar_url', new.raw_user_meta_data->>'picture', null),
    COALESCE(new.raw_app_meta_data->>'provider', 'email')
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = COALESCE(public.profiles.full_name, EXCLUDED.full_name),
    avatar_url = COALESCE(public.profiles.avatar_url, EXCLUDED.avatar_url);
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Profiles: Publicly viewable for group members & ledger balances
DROP POLICY IF EXISTS "Profiles are viewable by authenticated users" ON public.profiles;
CREATE POLICY "Profiles are viewable by authenticated users"
ON public.profiles FOR SELECT
USING (true);

-- Profiles: Users can update their own profile
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
ON public.profiles FOR UPDATE
USING (auth.uid() = id OR auth.uid() IS NULL);

-- Profiles: Users can insert their own profile
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile"
ON public.profiles FOR INSERT
WITH CHECK (auth.uid() = id OR auth.uid() IS NULL);

-- Cohorts: Members can view their cohorts; anyone can view by invite_code for joining
CREATE POLICY "Cohorts viewable by members or invite code lookup"
ON public.cohorts FOR SELECT
TO authenticated
USING (
    public.is_member_of_cohort(id)
    OR created_by = auth.uid()
    OR auth.uid() IS NOT NULL
);

-- Cohorts: Authenticated users can create cohorts
CREATE POLICY "Authenticated users can create cohorts"
ON public.cohorts FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = created_by);

-- Cohorts: Cohort members can update cohort details
CREATE POLICY "Members can update their cohorts"
ON public.cohorts FOR UPDATE
TO authenticated
USING (public.is_member_of_cohort(id));

-- Group Members: Members of a cohort can view its members
CREATE POLICY "Group members are viewable by cohort members"
ON public.group_members FOR SELECT
TO authenticated
USING (public.is_member_of_cohort(cohort_id) OR user_id = auth.uid());

-- Group Members: Users can insert their own membership or admins can add members
CREATE POLICY "Users can join cohorts or admins can add members"
ON public.group_members FOR INSERT
TO authenticated
WITH CHECK (
    user_id = auth.uid()
    OR public.is_member_of_cohort(cohort_id)
);

-- Expenses: Viewable by cohort members
CREATE POLICY "Expenses viewable by cohort members"
ON public.expenses FOR SELECT
TO authenticated
USING (public.is_member_of_cohort(cohort_id));

-- Expenses: Inserable by cohort members
CREATE POLICY "Expenses insertable by cohort members"
ON public.expenses FOR INSERT
TO authenticated
WITH CHECK (public.is_member_of_cohort(cohort_id));

-- Expenses: Updatable by cohort members
CREATE POLICY "Expenses updatable by cohort members"
ON public.expenses FOR UPDATE
TO authenticated
USING (public.is_member_of_cohort(cohort_id));

-- Expenses: Deletable by cohort members
CREATE POLICY "Expenses deletable by cohort members"
ON public.expenses FOR DELETE
TO authenticated
USING (public.is_member_of_cohort(cohort_id));

-- Expense Splits: Viewable and manageable by cohort members via parent expense
CREATE POLICY "Expense splits viewable by cohort members"
ON public.expense_splits FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.expenses
        WHERE expenses.id = expense_splits.expense_id
        AND public.is_member_of_cohort(expenses.cohort_id)
    )
);

CREATE POLICY "Expense splits insertable by cohort members"
ON public.expense_splits FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.expenses
        WHERE expenses.id = expense_splits.expense_id
        AND public.is_member_of_cohort(expenses.cohort_id)
    )
);

CREATE POLICY "Expense splits updatable/deletable by cohort members"
ON public.expense_splits FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.expenses
        WHERE expenses.id = expense_splits.expense_id
        AND public.is_member_of_cohort(expenses.cohort_id)
    )
);

-- Line Items & Assignments: Accessible to cohort members
CREATE POLICY "Line items accessible by cohort members"
ON public.line_items FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.expenses
        WHERE expenses.id = line_items.expense_id
        AND public.is_member_of_cohort(expenses.cohort_id)
    )
);

CREATE POLICY "Line item assignments accessible by cohort members"
ON public.line_item_assignments FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.line_items
        JOIN public.expenses ON expenses.id = line_items.expense_id
        WHERE line_items.id = line_item_assignments.line_item_id
        AND public.is_member_of_cohort(expenses.cohort_id)
    )
);

-- Comments: Viewable and insertable by cohort members
CREATE POLICY "Comments viewable by cohort members"
ON public.comments FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.expenses
        WHERE expenses.id = comments.expense_id
        AND public.is_member_of_cohort(expenses.cohort_id)
    )
);

CREATE POLICY "Comments insertable by cohort members"
ON public.comments FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
        SELECT 1 FROM public.expenses
        WHERE expenses.id = comments.expense_id
        AND public.is_member_of_cohort(expenses.cohort_id)
    )
);

-- Shared List Items: Full access to cohort members
CREATE POLICY "Shared list items managed by cohort members"
ON public.shared_list_items FOR ALL
TO authenticated
USING (public.is_member_of_cohort(cohort_id))
WITH CHECK (public.is_member_of_cohort(cohort_id));

-- Shortcuts: Managed by cohort members
CREATE POLICY "Shortcuts managed by cohort members"
ON public.expense_shortcuts FOR ALL
TO authenticated
USING (public.is_member_of_cohort(cohort_id))
WITH CHECK (public.is_member_of_cohort(cohort_id));

-- ============================================================================
-- STORAGE BUCKETS (RECEIPTS & AVATARS)
-- ============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('receipts', 'receipts', true), ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: Public read for receipts and avatars
CREATE POLICY "Public Read Receipts"
ON storage.objects FOR SELECT
USING (bucket_id IN ('receipts', 'avatars'));

-- Storage RLS: Authenticated upload
CREATE POLICY "Authenticated Upload Receipts"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id IN ('receipts', 'avatars'));
