import { authorizeCron, getSupabase, sendTelegramText, cairoDateParts, money } from './_report-utils.js';

// تذكير أقساط: يبعت على تليجرام قائمة الأقساط اللي هتستحق بعد يومين (غير المدفوعة
// واللي ما اتبعتش تذكيرها قبل كده). يشتغل يومياً عبر Vercel Cron (see vercel.json).
export default async function handler(req, res) {
  if (req.method !== 'GET' && req.method !== 'POST') {
    return res.status(405).json({ ok: false, error: 'Method not allowed' });
  }
  if (!authorizeCron(req)) {
    return res.status(401).json({ ok: false, error: 'Unauthorized' });
  }

  try {
    const supabase = getSupabase();

    // تاريخ بعد يومين بتوقيت القاهرة (due_date مخزّن YYYY-MM-DD)
    const { year, month, day } = cairoDateParts();
    const target = cairoDateParts(new Date(Date.UTC(year, month - 1, day + 2, 12, 0, 0)));
    const targetYmd = `${target.year}-${String(target.month).padStart(2, '0')}-${String(target.day).padStart(2, '0')}`;

    const { data: due, error } = await supabase
      .from('installments')
      .select('*')
      .eq('paid', false)
      .eq('notified', false)
      .eq('due_date', targetYmd);
    if (error) throw error;
    if (!due || due.length === 0) {
      return res.status(200).json({ ok: true, reminded: 0, date: targetYmd });
    }

    // بيانات العملاء + عملة المتجر
    const custIds = [...new Set(due.map((i) => i.customer_id).filter(Boolean))];
    const { data: custs } = await supabase.from('customers').select('id,name,phone').in('id', custIds);
    const cmap = new Map((custs || []).map((c) => [c.id, c]));
    let currency = 'ج.م';
    try {
      const { data: st } = await supabase.from('store_settings').select('currency').limit(1).maybeSingle();
      if (st?.currency) currency = st.currency;
    } catch { /* default */ }

    let total = 0;
    let lines = '';
    for (const i of due) {
      const c = cmap.get(i.customer_id) || {};
      total += Number(i.amount) || 0;
      lines += `• ${c.name || 'عميل'}${c.phone ? ` (${c.phone})` : ''} — القسط ${i.seq} — ${money(i.amount, currency)} — فاتورة #${i.order_id}\n`;
    }
    const msg =
      `🔔 تذكير تحصيل أقساط\n` +
      `مستحقة بعد يومين (${targetYmd}):\n\n` +
      lines +
      `\n💰 الإجمالي المستحق: ${money(total, currency)}\n` +
      `عدد الأقساط: ${due.length}`;

    await sendTelegramText(msg);

    // نعلّم إنه اتبعت عشان ما يتكررش
    await supabase.from('installments').update({ notified: true }).in('id', due.map((i) => i.id));

    return res.status(200).json({ ok: true, reminded: due.length, date: targetYmd });
  } catch (error) {
    return res.status(500).json({ ok: false, error: String(error) });
  }
}
