-- Migration: 20260915_enforce_user_capacity_and_webhook.sql
-- Enforces a 150-user registration hard-cap on public.profiles and auth.users
-- Tracks system-level milestone flags for one-time admin notifications

-- 1. System Settings / Milestones Table
CREATE TABLE IF NOT EXISTS public.system_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Initialize default 150 user cap settings
INSERT INTO public.system_settings (key, value)
VALUES (
    'user_capacity',
    jsonb_build_object(
        'max_users', 150,
        'milestone_notified', false,
        'notified_at', null
    )
)
ON CONFLICT (key) DO NOTHING;

-- Enable RLS on system_settings (read-only for authenticated, write only by service role)
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "System settings viewable by authenticated users" ON public.system_settings;
CREATE POLICY "System settings viewable by authenticated users"
ON public.system_settings FOR SELECT
TO authenticated
USING (true);

-- 2. Function to enforce the 150-user registration cap
CREATE OR REPLACE FUNCTION public.check_user_capacity_limit()
RETURNS TRIGGER AS $$
DECLARE
    current_count INT;
    max_capacity INT := 150;
    settings_val JSONB;
BEGIN
    -- Read dynamic cap from system_settings if available
    SELECT value INTO settings_val FROM public.system_settings WHERE key = 'user_capacity';
    IF settings_val IS NOT NULL AND (settings_val->>'max_users') IS NOT NULL THEN
        max_capacity := (settings_val->>'max_users')::INT;
    END IF;

    -- Count existing registered non-guest accounts
    SELECT COUNT(*) INTO current_count 
    FROM public.profiles 
    WHERE is_guest = false;

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

-- 3. Trigger on public.profiles
DROP TRIGGER IF EXISTS enforce_150_user_cap ON public.profiles;
CREATE TRIGGER enforce_150_user_cap
    BEFORE INSERT ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.check_user_capacity_limit();

-- 4. Update handle_new_user() on auth.users to check capacity before profile insertion
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    current_count INT;
    max_capacity INT := 150;
    settings_val JSONB;
BEGIN
    -- Read dynamic cap from system_settings if available
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

    -- Check non-guest user count
    SELECT COUNT(*) INTO current_count 
    FROM public.profiles 
    WHERE is_guest = false;

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
