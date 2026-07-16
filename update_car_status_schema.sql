ALTER TABLE public.car_subscriptions ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';
