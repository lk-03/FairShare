-- ============================================================================
-- Migration: Add Friendships, 1-on-1 Expenses & Bilateral Ledgers
-- Date: 2026-11-02
-- ============================================================================

-- 1. FRIENDSHIPS TABLE
CREATE TABLE IF NOT EXISTS public.friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id_1 UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    user_id_2 UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'accepted', -- 'pending' | 'accepted' | 'declined' | 'blocked'
    created_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_friendship_status CHECK (status IN ('pending', 'accepted', 'declined', 'blocked')),
    CONSTRAINT chk_friendship_distinct CHECK (user_id_1 != user_id_2),
    CONSTRAINT uq_friendship_pair UNIQUE(user_id_1, user_id_2)
);

CREATE INDEX IF NOT EXISTS idx_friendships_user1 ON public.friendships(user_id_1);
CREATE INDEX IF NOT EXISTS idx_friendships_user2 ON public.friendships(user_id_2);
CREATE INDEX IF NOT EXISTS idx_friendships_status ON public.friendships(status);

-- 2. MAKE EXPENSES COHORT_ID NULLABLE & ADD FRIENDSHIP_ID
ALTER TABLE public.expenses ALTER COLUMN cohort_id DROP NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'expenses' AND column_name = 'friendship_id'
    ) THEN
        ALTER TABLE public.expenses ADD COLUMN friendship_id UUID REFERENCES public.friendships(id) ON DELETE CASCADE;
    END IF;
END $$;

ALTER TABLE public.expenses DROP CONSTRAINT IF EXISTS chk_expense_destination;
ALTER TABLE public.expenses ADD CONSTRAINT chk_expense_destination 
    CHECK ((cohort_id IS NOT NULL AND friendship_id IS NULL) OR (cohort_id IS NULL AND friendship_id IS NOT NULL));

CREATE INDEX IF NOT EXISTS idx_expenses_friendship_created ON public.expenses(friendship_id, created_at DESC);

-- 3. HELPER FUNCTIONS
CREATE OR REPLACE FUNCTION public.is_friend_of_friendship(f_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.friendships
        WHERE id = f_id
        AND (user_id_1 = auth.uid() OR user_id_2 = auth.uid())
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- 4. RLS POLICIES FOR FRIENDSHIPS
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Friendships viewable by involved users" ON public.friendships;
CREATE POLICY "Friendships viewable by involved users"
ON public.friendships FOR SELECT
TO authenticated
USING (user_id_1 = auth.uid() OR user_id_2 = auth.uid());

DROP POLICY IF EXISTS "Users can create friendships" ON public.friendships;
CREATE POLICY "Users can create friendships"
ON public.friendships FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = created_by 
    AND (user_id_1 = auth.uid() OR user_id_2 = auth.uid())
);

DROP POLICY IF EXISTS "Involved users can update friendship" ON public.friendships;
CREATE POLICY "Involved users can update friendship"
ON public.friendships FOR UPDATE
TO authenticated
USING (user_id_1 = auth.uid() OR user_id_2 = auth.uid());

DROP POLICY IF EXISTS "Involved users can delete friendship" ON public.friendships;
CREATE POLICY "Involved users can delete friendship"
ON public.friendships FOR DELETE
TO authenticated
USING (user_id_1 = auth.uid() OR user_id_2 = auth.uid());

-- 5. UPDATE RLS POLICIES FOR EXPENSES
DROP POLICY IF EXISTS "Expenses viewable by cohort members" ON public.expenses;
DROP POLICY IF EXISTS "Expenses viewable by members or friends" ON public.expenses;
CREATE POLICY "Expenses viewable by members or friends"
ON public.expenses FOR SELECT
TO authenticated
USING (
    (cohort_id IS NOT NULL AND public.is_member_of_cohort(cohort_id))
    OR (friendship_id IS NOT NULL AND public.is_friend_of_friendship(friendship_id))
);

DROP POLICY IF EXISTS "Expenses insertable by cohort members" ON public.expenses;
DROP POLICY IF EXISTS "Expenses insertable by members or friends" ON public.expenses;
CREATE POLICY "Expenses insertable by members or friends"
ON public.expenses FOR INSERT
TO authenticated
WITH CHECK (
    (cohort_id IS NOT NULL AND public.is_member_of_cohort(cohort_id))
    OR (friendship_id IS NOT NULL AND public.is_friend_of_friendship(friendship_id))
);

DROP POLICY IF EXISTS "Expenses updatable by cohort members" ON public.expenses;
DROP POLICY IF EXISTS "Expenses updatable by members or friends" ON public.expenses;
CREATE POLICY "Expenses updatable by members or friends"
ON public.expenses FOR UPDATE
TO authenticated
USING (
    (cohort_id IS NOT NULL AND public.is_member_of_cohort(cohort_id))
    OR (friendship_id IS NOT NULL AND public.is_friend_of_friendship(friendship_id))
);

DROP POLICY IF EXISTS "Expenses deletable by cohort members" ON public.expenses;
DROP POLICY IF EXISTS "Expenses deletable by members or friends" ON public.expenses;
CREATE POLICY "Expenses deletable by members or friends"
ON public.expenses FOR DELETE
TO authenticated
USING (
    (cohort_id IS NOT NULL AND public.is_member_of_cohort(cohort_id))
    OR (friendship_id IS NOT NULL AND public.is_friend_of_friendship(friendship_id))
);

-- 6. UPDATE RLS POLICIES FOR EXPENSE SPLITS
DROP POLICY IF EXISTS "Expense splits viewable by cohort members" ON public.expense_splits;
DROP POLICY IF EXISTS "Expense splits viewable by members or friends" ON public.expense_splits;
CREATE POLICY "Expense splits viewable by members or friends"
ON public.expense_splits FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.expenses e
        WHERE e.id = expense_splits.expense_id
        AND (
            (e.cohort_id IS NOT NULL AND public.is_member_of_cohort(e.cohort_id))
            OR (e.friendship_id IS NOT NULL AND public.is_friend_of_friendship(e.friendship_id))
        )
    )
);

DROP POLICY IF EXISTS "Expense splits insertable by cohort members" ON public.expense_splits;
DROP POLICY IF EXISTS "Expense splits insertable by members or friends" ON public.expense_splits;
CREATE POLICY "Expense splits insertable by members or friends"
ON public.expense_splits FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.expenses e
        WHERE e.id = expense_splits.expense_id
        AND (
            (e.cohort_id IS NOT NULL AND public.is_member_of_cohort(e.cohort_id))
            OR (e.friendship_id IS NOT NULL AND public.is_friend_of_friendship(e.friendship_id))
        )
    )
);

-- 7. UPDATE RLS POLICIES FOR EXPENSE PAYERS
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'expense_payers') THEN
        DROP POLICY IF EXISTS "Expense payers viewable by cohort members" ON public.expense_payers;
        DROP POLICY IF EXISTS "Expense payers viewable by members or friends" ON public.expense_payers;
        CREATE POLICY "Expense payers viewable by members or friends"
        ON public.expense_payers FOR SELECT
        TO authenticated
        USING (
            EXISTS (
                SELECT 1 FROM public.expenses e
                WHERE e.id = expense_payers.expense_id
                AND (
                    (e.cohort_id IS NOT NULL AND public.is_member_of_cohort(e.cohort_id))
                    OR (e.friendship_id IS NOT NULL AND public.is_friend_of_friendship(e.friendship_id))
                )
            )
        );

        DROP POLICY IF EXISTS "Expense payers insertable by cohort members" ON public.expense_payers;
        DROP POLICY IF EXISTS "Expense payers insertable by members or friends" ON public.expense_payers;
        CREATE POLICY "Expense payers insertable by members or friends"
        ON public.expense_payers FOR INSERT
        TO authenticated
        WITH CHECK (
            EXISTS (
                SELECT 1 FROM public.expenses e
                WHERE e.id = expense_payers.expense_id
                AND (
                    (e.cohort_id IS NOT NULL AND public.is_member_of_cohort(e.cohort_id))
                    OR (e.friendship_id IS NOT NULL AND public.is_friend_of_friendship(e.friendship_id))
                )
            )
        );
    END IF;
END $$;
