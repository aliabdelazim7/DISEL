const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://gynfppklsussrhpsovic.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5bmZwcGtsc3Vzc3JocHNvdmljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczMzQ5NDgsImV4cCI6MjA5MjkxMDk0OH0.1NXnbstnLlyyIqHfQ9IKWQc1zNkqnWh9hVX4Uz3jfLc'
);

async function testUpdate() {
  const { data: existing, error: selectError } = await supabase.from('store_settings').select('id').limit(1).maybeSingle();
  console.log("Existing:", existing, "Select Error:", selectError);

  if (existing?.id) {
    const { data, error } = await supabase.from('store_settings').update({ theme_color: '#e54048' }).eq('id', existing.id).select();
    console.log("Update Data:", data, "Update Error:", error);
  }
}

testUpdate();
