-- ============================================================================
-- FAIRSHARE MIGRATION: Group Deletion, 15-Day Archive & Admin Succession
-- Date: 2026-09-02
-- ============================================================================

-- 1. Add Archive & 15-Day Trash Deletion Tracking to Cohorts Table
ALTER TABLE public.cohorts 
ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_cohorts_archived ON public.cohorts(is_archived, archived_at);
CREATE INDEX IF NOT EXISTS idx_cohorts_deleted ON public.cohorts(is_deleted, deleted_at);

-- 2. Allow Group-Level System Notifications & Comments (e.g. Member Kicked, Admin Succession)
ALTER TABLE public.comments 
ALTER COLUMN expense_id DROP NOT NULL;

ALTER TABLE public.comments 
ADD COLUMN IF NOT EXISTS cohort_id UUID REFERENCES public.cohorts(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_comments_cohort ON public.comments(cohort_id);

-- 3. Cohorts Delete Policy (Admins can delete cohorts)
DROP POLICY IF EXISTS "Admins can delete their cohorts" ON public.cohorts;
CREATE POLICY "Admins can delete their cohorts"
ON public.cohorts FOR DELETE
TO authenticated
USING (
    created_by = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.group_members gm
        WHERE gm.cohort_id = public.cohorts.id
        AND gm.user_id = auth.uid()
        AND gm.role = 'admin'
    )
);

-- 4. Group Members: Delete Policy (Members can leave, Admins can kick)
DROP POLICY IF EXISTS "Members can leave or admins can kick members" ON public.group_members;
CREATE POLICY "Members can leave or admins can kick members"
ON public.group_members FOR DELETE
TO authenticated
USING (
    user_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.cohorts
        WHERE cohorts.id = group_members.cohort_id
        AND cohorts.created_by = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.group_members gm
        WHERE gm.cohort_id = group_members.cohort_id
        AND gm.user_id = auth.uid()
        AND gm.role = 'admin'
    )
);

-- 5. Group Members: Update Policy (Admins can transfer admin roles / succession)
DROP POLICY IF EXISTS "Admins can update member roles" ON public.group_members;
CREATE POLICY "Admins can update member roles"
ON public.group_members FOR UPDATE
TO authenticated
USING (
    user_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.cohorts
        WHERE cohorts.id = group_members.cohort_id
        AND cohorts.created_by = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.group_members gm
        WHERE gm.cohort_id = group_members.cohort_id
        AND gm.user_id = auth.uid()
        AND gm.role = 'admin'
    )
);

-- 6. Comments Policy: Support both Expense Comments & Cohort Activity Broadcasts
DROP POLICY IF EXISTS "Comments viewable by cohort members" ON public.comments;
CREATE POLICY "Comments viewable by cohort members"
ON public.comments FOR SELECT
TO authenticated
USING (
    (cohort_id IS NOT NULL AND public.is_member_of_cohort(cohort_id))
    OR (expense_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.expenses
        WHERE expenses.id = comments.expense_id
        AND public.is_member_of_cohort(expenses.cohort_id)
    ))
);

DROP POLICY IF EXISTS "Comments insertable by cohort members" ON public.comments;
CREATE POLICY "Comments insertable by cohort members"
ON public.comments FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id
    AND (
        (cohort_id IS NOT NULL AND public.is_member_of_cohort(cohort_id))
        OR (expense_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.expenses
            WHERE expenses.id = comments.expense_id
            AND public.is_member_of_cohort(expenses.cohort_id)
        ))
    )
);

-- 7. Update new user trigger to avoid placeholder 'User' names
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, avatar_url, auth_provider)
  VALUES (
    new.id,
    new.email,
    COALESCE(
      new.raw_user_meta_data->>'full_name', 
      new.raw_user_meta_data->>'name', 
      NULLIF(split_part(new.email, '@', 1), ''), 
      'You'
    ),
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
