-- ============================================================================
-- FAIRSHARE: DATABASE SCHEMA & MODEL CLEANUP MIGRATION
-- ============================================================================
-- Drops deprecated columns, removes dead receipt calculation fields, drops legacy
-- line item draft tables, and updates triggers to eliminate obsolete references.
-- ============================================================================

-- 1. CLEANUP PUBLIC.PROFILES
-- Remove deprecated guest user flag
ALTER TABLE public.profiles DROP COLUMN IF EXISTS is_guest;

-- Update check_user_capacity_limit() trigger to count all profiles
CREATE OR REPLACE FUNCTION public.check_user_capacity_limit()
RETURNS TRIGGER AS $$
DECLARE
    current_count INT;
    max_capacity INT := 150;
    settings_val JSONB;
BEGIN
    SELECT value INTO settings_val FROM public.system_settings WHERE key = 'user_capacity';
    IF settings_val IS NOT NULL AND (settings_val->>'max_users') IS NOT NULL THEN
        max_capacity := (settings_val->>'max_users')::INT;
    END IF;

    -- Count all registered user accounts
    SELECT COUNT(*) INTO current_count 
    FROM public.profiles;

    -- If user already exists in profiles, this is an update/upsert — allow it
    IF EXISTS (SELECT 1 FROM public.profiles WHERE id = NEW.id) THEN
        RETURN NEW;
    END IF;

    -- If capacity is reached, block new user creation
    IF current_count >= max_capacity THEN
        RAISE EXCEPTION 'CAPACITY_REACHED: FairShare has reached its 150-user early access limit.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update handle_new_user() trigger function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    current_count INT;
    max_capacity INT := 150;
    settings_val JSONB;
BEGIN
    SELECT value INTO settings_val FROM public.system_settings WHERE key = 'user_capacity';
    IF settings_val IS NOT NULL AND (settings_val->>'max_users') IS NOT NULL THEN
        max_capacity := (settings_val->>'max_users')::INT;
    END IF;

    -- If this is an existing user updating their record, allow it
    IF EXISTS (SELECT 1 FROM public.profiles WHERE id = NEW.id) THEN
        UPDATE public.profiles SET
            email = NEW.email,
            full_name = COALESCE(public.profiles.full_name, NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1), 'User'),
            avatar_url = COALESCE(public.profiles.avatar_url, NEW.raw_user_meta_data->>'avatar_url', NEW.raw_user_meta_data->>'picture', null)
        WHERE id = NEW.id;
        RETURN NEW;
    END IF;

    -- Check total user count
    SELECT COUNT(*) INTO current_count 
    FROM public.profiles;

    IF current_count >= max_capacity THEN
        RAISE EXCEPTION 'CAPACITY_REACHED: FairShare has reached its 150-user early access limit.';
    END IF;

    INSERT INTO public.profiles (id, email, full_name, avatar_url, auth_provider)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1), 'User'),
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', NEW.raw_user_meta_data->>'picture', null),
        COALESCE(NEW.raw_app_meta_data->>'provider', 'email')
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. CLEANUP PUBLIC.COHORTS
-- Remove duplicate / unused banner column
ALTER TABLE public.cohorts DROP COLUMN IF EXISTS banner_url;


-- 3. CLEANUP PUBLIC.EXPENSES
-- Remove legacy OCR parsing boolean and obsolete receipt calculation residues
ALTER TABLE public.expenses DROP COLUMN IF EXISTS ocr_parsed;
ALTER TABLE public.expenses DROP COLUMN IF EXISTS subtotal;
ALTER TABLE public.expenses DROP COLUMN IF EXISTS tax_amount;
ALTER TABLE public.expenses DROP COLUMN IF EXISTS service_charge;
ALTER TABLE public.expenses DROP COLUMN IF EXISTS discount_amount;


-- 4. CLEANUP LEGACY LINE ITEMS TABLES & ARRAYS
-- Drop obsolete server-side line item draft tables
DROP TABLE IF EXISTS public.line_item_assignments CASCADE;
DROP TABLE IF EXISTS public.line_items CASCADE;
ALTER TABLE public.expense_splits DROP COLUMN IF EXISTS line_item_ids;
