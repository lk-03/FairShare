-- ============================================================================
-- FAIRSHARE MIGRATION: Fix RLS Infinite Recursion on Group Members
-- Date: 2026-10-11
-- ============================================================================
-- Resolves Postgres error 42P17 (infinite recursion detected in policy for relation "group_members")
-- by using a SECURITY DEFINER helper function to safely look up group memberships.
-- ============================================================================

-- 1. Helper function running as SECURITY DEFINER with explicit search_path
-- This executes with table-owner privileges, breaking recursive RLS checks on group_members.
CREATE OR REPLACE FUNCTION public.get_user_cohort_ids(user_uuid UUID)
RETURNS SETOF UUID AS $$
    SELECT cohort_id FROM public.group_members WHERE user_id = user_uuid;
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public;

-- 2. Hardened is_member_of_cohort function with explicit search_path
CREATE OR REPLACE FUNCTION public.is_member_of_cohort(cohort_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.group_members
        WHERE group_members.cohort_id = $1
        AND group_members.user_id = auth.uid()
    );
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public;

-- 3. Replace recursive SELECT policy on public.group_members
DROP POLICY IF EXISTS "Group members are viewable by cohort members" ON public.group_members;

CREATE POLICY "Group members are viewable by cohort members"
ON public.group_members FOR SELECT
TO authenticated
USING (
    user_id = auth.uid()
    OR cohort_id IN (SELECT public.get_user_cohort_ids(auth.uid()))
);

-- 4. Ensure INSERT policy on public.group_members is non-recursive
DROP POLICY IF EXISTS "Users can join cohorts or admins can add members" ON public.group_members;

CREATE POLICY "Users can join cohorts or admins can add members"
ON public.group_members FOR INSERT
TO authenticated
WITH CHECK (
    user_id = auth.uid()
    OR cohort_id IN (SELECT public.get_user_cohort_ids(auth.uid()))
);
