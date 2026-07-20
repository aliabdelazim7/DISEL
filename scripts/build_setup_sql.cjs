/**
 * يولّد SETUP_DIESEL.sql من ملفات db/ — شغّله بعد أي ميجريشن جديدة:
 *     node scripts/build_setup_sql.cjs
 *
 * الملف الموحّد كان متعمول بالإيد، فأول ما اتضافت ميجريشنز جديدة (26→30)
 * فضل قديم من غير ما حد ياخد باله — ونسخة جديدة كانت هتتعمل ناقصة جداول.
 * التوليد من db/ بيمنع ده.
 *
 * الترتيب: 01 (الجداول الأساسية) ← 00 (إكمال أعمدة/قيود) ← الباقي بالترتيب الرقمي.
 */
const fs = require('fs');
const path = require('path');

const DB_DIR = path.join(__dirname, '..', 'db');
const OUT = path.join(__dirname, '..', 'SETUP_DIESEL.sql');

// ملفات مش جزء من الإعداد:
//   12_reset_data       → أداة مسح بيانات، لو اتحطت هنا هتفضّي الداتابيز
//   32_reset_and_seed_barbershop → نفس الحكاية: بيعمل truncate لكل الجداول
//                          وبيعيد زرع أصناف الباربر شوب. أداة تشغّلها بإيدك
//                          لما تعوز تبدأ من الصفر، مش جزء من إعداد قاعدة جديدة.
//   secure_rls_migration → تشديد أمان اختياري، بيتشغّل لوحده بعد ما التطبيق يشتغل
//   seed_products_catalog → منتجات جاهزة، اختيارية حسب المحل
//   34_reset_and_seed_diesel_services → كتالوج خدمات الديزل + تصفير كامل،
//                          نفس السبب: أداة بالإيد مش جزء من إعداد قاعدة جديدة.
const EXCLUDE = new Set([
  '12_reset_data.sql',
  '32_reset_and_seed_barbershop.sql',
  '34_reset_and_seed_diesel_services.sql',
  'secure_rls_migration.sql',
  'seed_products_catalog.sql',
]);

const numOf = (f) => {
  const m = /^(\d+)_/.exec(f);
  return m ? Number(m[1]) : Number.MAX_SAFE_INTEGER;
};

const files = fs.readdirSync(DB_DIR)
  .filter((f) => f.endsWith('.sql') && !EXCLUDE.has(f))
  .sort((a, b) => numOf(a) - numOf(b));

// 00 لازم يجي بعد 01: بيعمل alter على جداول 01 بينشئها.
const base = files.filter((f) => numOf(f) === 1);
const extras = files.filter((f) => numOf(f) === 0);
const rest = files.filter((f) => numOf(f) > 1);
const ordered = [...base, ...extras, ...rest];

if (base.length === 0) {
  console.error('❌ مفيش ملف 01_*.sql — مش هينفع أولّد من غير الجداول الأساسية.');
  process.exit(1);
}

const header = `-- ============================================================================
-- DIESEL Barbershop — إعداد قاعدة البيانات كاملة من الصفر (ملف واحد)
-- شغّله مرة واحدة بالكامل في: Supabase → SQL Editor → New query → Run
--
-- ⚠️  الـ SQL لوحده مش كفاية — التطبيق بيسجّل دخول بـ Supabase Auth
--     (signInWithPassword)، فلازم تعمل مستخدم Auth بعد كده وإلا مش هتقدر تدخل:
--         node scripts/provision_auth_users.cjs
--     الترتيب الكامل في SECURITY_SETUP.md.
--
--  الجداول القديمة بتتعمل بصلاحيات RLS مفتوحة (allow all) عشان التطبيق يشتغل
--  فورًا، والجداول الأحدث (held_invoices / installments / quotations /
--  attendance) بتقفل نفسها على authenticated من أول لحظة — ودي شغالة عادي لأن
--  التطبيق بيدخل كـ authenticated.
--  لتشديد الباقي: شغّل db/secure_rls_migration.sql بعد ما تتأكد إن الدخول شغال.
--
-- ⚠️  مولّد آليًا — لا تعدّله بالإيد.
--     أضف ميجريشن في db/ ثم شغّل: node scripts/build_setup_sql.cjs
-- ============================================================================

`;

const body = ordered.map((f) => {
  const sql = fs.readFileSync(path.join(DB_DIR, f), 'utf8').trim();
  return `\n\n-- ========================= ${f} =========================\n${sql}\n`;
}).join('');

fs.writeFileSync(OUT, header + body, 'utf8');

console.log(`✅ اتولّد ${path.basename(OUT)} من ${ordered.length} ملف:`);
ordered.forEach((f) => console.log(`     ${f}`));
console.log(`\n   مستبعد عن قصد: ${[...EXCLUDE].join(', ')}`);
console.log(`   الحجم: ${(fs.statSync(OUT).size / 1024).toFixed(1)} KB`);
