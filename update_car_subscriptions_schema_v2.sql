ALTER TABLE public.car_subscriptions ADD COLUMN IF NOT EXISTS subscription_duration_months INTEGER;
ALTER TABLE public.car_subscriptions ADD COLUMN IF NOT EXISTS subscription_frequency_days INTEGER;
