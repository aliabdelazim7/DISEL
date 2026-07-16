-- ============================================================
-- Cashier Management Table & Schema Updates
-- Run this in your Supabase SQL Editor
-- ============================================================

-- 1. Create the cashiers table
CREATE TABLE IF NOT EXISTS cashiers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  password TEXT,
  phone TEXT,
  photo_url TEXT, -- This will store the base64 image or a URL
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Add cashier_name to orders table to track who made the sale
ALTER TABLE orders ADD COLUMN IF NOT EXISTS cashier_name TEXT;

-- 3. Enable RLS (Row Level Security)
ALTER TABLE cashiers ENABLE ROW LEVEL SECURITY;

-- 4. Create "allow all" policy for cashiers (matching existing patterns)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'cashiers' AND policyname = 'allow all'
    ) THEN
        CREATE POLICY "allow all" ON cashiers FOR ALL USING (true) WITH CHECK (true);
    END IF;
END
$$;
