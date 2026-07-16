-- إنشاء جدول السيارات / الاشتراكات
CREATE TABLE IF NOT EXISTS public.car_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    car_number TEXT NOT NULL,
    car_details TEXT,
    customer_name TEXT,
    customer_phone TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- إنشاء جدول مواعيد الصيانة
CREATE TABLE IF NOT EXISTS public.maintenance_appointments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subscription_id UUID NOT NULL REFERENCES public.car_subscriptions(id) ON DELETE CASCADE,
    appointment_date DATE NOT NULL,
    description TEXT,
    report TEXT,
    cost NUMERIC DEFAULT 0,
    status TEXT DEFAULT 'pending', -- 'pending' أو 'completed'
    is_reminded BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- تفعيل Realtime للجداول
ALTER PUBLICATION supabase_realtime ADD TABLE car_subscriptions;
ALTER PUBLICATION supabase_realtime ADD TABLE maintenance_appointments;

-- السماح بالصلاحيات (Policies) في حال كان Row Level Security مفعل
ALTER TABLE public.car_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_appointments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all actions for authenticated users on car_subscriptions"
    ON public.car_subscriptions
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow all actions for anon on car_subscriptions"
    ON public.car_subscriptions
    FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow all actions for authenticated users on maintenance_appointments"
    ON public.maintenance_appointments
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow all actions for anon on maintenance_appointments"
    ON public.maintenance_appointments
    FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);
