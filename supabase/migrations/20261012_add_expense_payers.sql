-- ============================================================================
-- FAIRSHARE: MULTI-PAYER EXPENSES SCHEMA MIGRATION
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.expense_payers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_id UUID NOT NULL REFERENCES public.expenses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_expense_payer UNIQUE (expense_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_expense_payers_expense ON public.expense_payers(expense_id);
CREATE INDEX IF NOT EXISTS idx_expense_payers_user ON public.expense_payers(user_id);

ALTER TABLE public.expense_payers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view expense payers"
    ON public.expense_payers FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.expenses e
            JOIN public.group_members gm ON gm.cohort_id = e.cohort_id
            WHERE e.id = public.expense_payers.expense_id
            AND gm.user_id = auth.uid()
        )
    );

CREATE POLICY "Members can insert expense payers"
    ON public.expense_payers FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.expenses e
            JOIN public.group_members gm ON gm.cohort_id = e.cohort_id
            WHERE e.id = public.expense_payers.expense_id
            AND gm.user_id = auth.uid()
        )
    );

CREATE POLICY "Members can update expense payers"
    ON public.expense_payers FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.expenses e
            JOIN public.group_members gm ON gm.cohort_id = e.cohort_id
            WHERE e.id = public.expense_payers.expense_id
            AND gm.user_id = auth.uid()
        )
    );

CREATE POLICY "Members can delete expense payers"
    ON public.expense_payers FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.expenses e
            JOIN public.group_members gm ON gm.cohort_id = e.cohort_id
            WHERE e.id = public.expense_payers.expense_id
            AND gm.user_id = auth.uid()
        )
    );
