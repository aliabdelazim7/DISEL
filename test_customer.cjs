const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://gynfppklsussrhpsovic.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5bmZwcGtsc3Vzc3JocHNvdmljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczMzQ5NDgsImV4cCI6MjA5MjkxMDk0OH0.1NXnbstnLlyyIqHfQ9IKWQc1zNkqnWh9hVX4Uz3jfLc'
);

async function testCustomer() {
  const { data, error } = await supabase
    .from('customers')
    .insert({ name: 'Test Customer', phone: '0123456789' })
    .select()
    .single();
    
  console.log("Data:", data);
  console.log("Error:", error);
}

testCustomer();
