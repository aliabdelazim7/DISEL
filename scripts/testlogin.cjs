// Quick diagnostic: try the admin login exactly like the browser does
// (anon key + email + password). Run:  node scripts/testlogin.cjs
const { createClient } = require('@supabase/supabase-js');

const URL = 'https://edprvtiotizjkslhzqet.supabase.co';
const ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVkcHJ2dGlvdGl6amtzbGh6cWV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI1NzA3MTIsImV4cCI6MjA5ODE0NjcxMn0.YSzO7kCbNJ0ECkewEZcxu4aFHGEbywd4P7boInP2H2w';

const EMAIL = 'adriaeg77@gmail.com';
const PASSWORD = '1260770';

const s = createClient(URL, ANON);
s.auth.signInWithPassword({ email: EMAIL, password: PASSWORD })
  .then(({ data, error }) => {
    if (error) console.log('FAIL: ' + error.message);
    else console.log('OK دخل: ' + data.user.email);
  })
  .catch((e) => console.error(e));
