// يحوّل رقم/أرقام الهاتف المخزّنة إلى رقم واتساب دولي صالح.
// يتعامل مع: أكتر من رقم في نفس الحقل (مفصولين بـ / أو | أو مسافة …)،
// البادئة الدولية 00، الصفر البادئ، والرقمين الملزوقين بدون فاصل.
export function toWhatsAppPhone(raw: string | undefined | null, countryCode = '20'): string {
  const code = (String(countryCode || '').replace(/\D/g, '')) || '20';
  const s = String(raw || '');

  // نفصل على أي شيء غير رقم، ونأخذ أول مجموعة أرقام «صالحة» (10 خانات فأكثر).
  const groups = s.split(/[^\d]+/).map((g) => g.replace(/\D/g, '')).filter(Boolean);
  let clean = groups.find((g) => g.length >= 10) || groups[0] || '';
  if (!clean) return '';

  // لو رقمين ملزوقين من غير فاصل (طويل جداً) → نأخذ أول رقم منطقي.
  if (clean.length > 13) clean = clean.startsWith('0') ? clean.slice(0, 11) : clean.slice(0, 10);

  if (clean.startsWith('00')) clean = clean.slice(2);        // بادئة دولية 00
  if (clean.startsWith('0')) clean = code + clean.slice(1);   // صفر محلي → كود الدولة
  else if (!clean.startsWith(code)) clean = code + clean;     // بدون كود → نضيفه

  return clean;
}

// يبني رابط واتساب جاهز (يفتح المحادثة بالرسالة).
export function waLink(rawPhone: string | undefined | null, text: string, countryCode = '20'): string | null {
  const phone = toWhatsAppPhone(rawPhone, countryCode);
  if (!phone || phone.length < 10) return null;
  return `https://wa.me/${phone}?text=${encodeURIComponent(text)}`;
}
