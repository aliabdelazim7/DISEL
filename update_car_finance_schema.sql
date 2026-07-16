-- ربط الإيرادات (المبيعات) بالسيارة
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS car_id UUID REFERENCES public.car_subscriptions(id) ON DELETE SET NULL;

-- ربط المصروفات بالسيارة
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS car_id UUID REFERENCES public.car_subscriptions(id) ON DELETE SET NULL;
