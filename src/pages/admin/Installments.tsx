import { useMemo, useState } from 'react';
import { useStore } from '../../store/useStore';
import { CalendarClock, AlertTriangle, Wallet, CheckCircle2, Clock, Plus, Receipt, MessageCircle, X } from 'lucide-react';
import { activePaymentKeys, payLabelOf } from '../../utils/paymentMethods';
import { waLink } from '../../utils/waPhone';

const ymd = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

export default function Installments() {
  const { customers, orders, installmentPlans, installments, createInstallmentPlan, collectInstallment, storeSettings } = useStore();
  const cur = storeSettings.currency;
  const payKeys = activePaymentKeys(storeSettings as any);
  const [tab, setTab] = useState<'collect' | 'create'>('collect');
  const [busy, setBusy] = useState(false);
  const [collectMethod, setCollectMethod] = useState<Record<string, string>>({});

  const today = ymd(new Date());
  const custName = (id: string) => customers.find((c) => c.id === id)?.name || 'عميل';
  const custPhone = (id: string) => customers.find((c) => c.id === id)?.phone || '';
  const daysUntil = (due: string) => Math.round((new Date(due + 'T12:00:00').getTime() - new Date(today + 'T12:00:00').getTime()) / 86400000);

  // ── تذكير واتساب للقسط ──
  const [noteModal, setNoteModal] = useState<{ inst: any; insts: any[]; note: string } | null>(null);

  const buildReminderMsg = (inst: any, insts: any[], note = '') => {
    const name = custName(inst.customer_id);
    const shop = storeSettings.name || 'المحل';
    const paidSum = insts.filter((i) => i.paid).reduce((s, i) => s + (Number(i.amount) || 0), 0);
    const remainingSum = insts.filter((i) => !i.paid).reduce((s, i) => s + (Number(i.amount) || 0), 0);
    const totalDue = insts.reduce((s, i) => s + (Number(i.amount) || 0), 0);
    const nextUnpaid = [...insts].sort((a, b) => a.seq - b.seq).find((i) => !i.paid);
    const d = daysUntil(inst.due_date);
    const dueLine = d > 0 ? `متبقّي ${d} يوم على الاستحقاق` : d === 0 ? 'مستحق اليوم ⏰' : `⚠️ متأخّر ${-d} يوم عن موعده`;
    let msg = `🔔 *تذكير قسط — ${shop}*\n`;
    msg += `عزيزنا ${name} 🌟\n\n`;
    msg += `بخصوص فاتورة التقسيط #${inst.order_id}:\n`;
    msg += `• القسط رقم *${inst.seq}* من ${insts.length}\n`;
    msg += `• قيمة القسط: *${(Number(inst.amount) || 0).toFixed(2)} ${cur}*\n`;
    msg += `• تاريخ الاستحقاق: ${inst.due_date}\n`;
    msg += `• ${dueLine}\n\n`;
    msg += `📋 *ملخّص التقسيط:*\n`;
    msg += `• إجمالي التقسيط: ${totalDue.toFixed(2)} ${cur}\n`;
    msg += `• المُسدَّد: ${paidSum.toFixed(2)} ${cur}\n`;
    msg += `• المتبقّي: ${remainingSum.toFixed(2)} ${cur}\n`;
    if (nextUnpaid) {
      const nd = daysUntil(nextUnpaid.due_date);
      msg += `• التحصيل القادم: ${nextUnpaid.due_date} (${nd > 0 ? `بعد ${nd} يوم` : nd === 0 ? 'اليوم' : `متأخّر ${-nd} يوم`})\n`;
    }
    if (note.trim()) msg += `\n📝 ${note.trim()}\n`;
    msg += `\nبرجاء التكرم بالسداد في موعده. شكراً لتعاملكم معنا 🙏\n${shop}${storeSettings.phone ? ` — ${storeSettings.phone}` : ''}`;
    return msg;
  };

  const sendReminder = (inst: any, insts: any[], note = '') => {
    const link = waLink(custPhone(inst.customer_id), buildReminderMsg(inst, insts, note), (storeSettings as any).whatsappCountryCode || '20');
    if (!link) { alert('رقم هاتف العميل غير صالح أو غير موجود.'); return; }
    window.open(link, '_blank');
  };

  // متأخّر → بوب أب ملاحظة (غرامة) قبل الإرسال؛ غير كده → إرسال مباشر.
  const onReminderClick = (inst: any, insts: any[]) => {
    if (daysUntil(inst.due_date) < 0) setNoteModal({ inst, insts, note: '' });
    else sendReminder(inst, insts);
  };

  // ── ملخّص ──
  const unpaid = installments.filter((i) => !i.paid);
  const totalOutstanding = unpaid.reduce((s, i) => s + (Number(i.amount) || 0), 0);
  const overdue = unpaid.filter((i) => i.due_date < today);
  const overdueTotal = overdue.reduce((s, i) => s + (Number(i.amount) || 0), 0);
  const thisMonth = today.slice(0, 7);
  const dueThisMonthTotal = unpaid.filter((i) => i.due_date.slice(0, 7) === thisMonth).reduce((s, i) => s + (Number(i.amount) || 0), 0);
  const activePlansCount = installmentPlans.filter((p) => p.status === 'active').length;

  // حالة القسط
  const statusOf = (due: string, paid: boolean) => {
    if (paid) return { key: 'paid', label: 'مدفوع', cls: 'text-emerald-600 bg-emerald-50' };
    const days = Math.round((new Date(due + 'T12:00:00').getTime() - new Date(today + 'T12:00:00').getTime()) / 86400000);
    if (days < 0) return { key: 'overdue', label: `متأخّر ${-days} يوم`, cls: 'text-red-600 bg-red-50' };
    if (days <= 2) return { key: 'due', label: days === 0 ? 'مستحق اليوم' : `باقي ${days} يوم`, cls: 'text-amber-700 bg-amber-50' };
    return { key: 'upcoming', label: `بعد ${days} يوم`, cls: 'text-slate-500 bg-slate-100' };
  };

  // ── التحصيلات: الخطط النشطة مرتّبة بأقرب استحقاق غير مدفوع ──
  const plansView = useMemo(() => {
    return installmentPlans
      .map((p) => {
        const insts = installments.filter((i) => i.plan_id === p.id).sort((a, b) => a.seq - b.seq);
        const paidCount = insts.filter((i) => i.paid).length;
        const remaining = insts.filter((i) => !i.paid).reduce((s, i) => s + (Number(i.amount) || 0), 0);
        const nextUnpaid = insts.find((i) => !i.paid);
        return { p, insts, paidCount, remaining, nextDue: nextUnpaid?.due_date || '9999' };
      })
      .filter((x) => x.insts.length > 0)
      .sort((a, b) => {
        // النشطة أولاً، ثم بأقرب استحقاق
        if (a.p.status !== b.p.status) return a.p.status === 'active' ? -1 : 1;
        return a.nextDue.localeCompare(b.nextDue);
      });
  }, [installmentPlans, installments]);

  const handleCollect = async (inst: any) => {
    const method = collectMethod[inst.id] || 'cash';
    if (!window.confirm(`تأكيد تحصيل القسط رقم ${inst.seq} بمبلغ ${Number(inst.amount).toFixed(2)} ${cur} من ${custName(inst.customer_id)}؟`)) return;
    setBusy(true);
    const split: any = { cash: 0, visa: 0, wallet: 0, instapay: 0, method5: 0, method6: 0 };
    split[method] = Number(inst.amount) || 0;
    const ok = await collectInstallment(inst.id, split, method);
    setBusy(false);
    if (ok) alert('تم تحصيل القسط بنجاح ✅');
  };

  // ── إنشاء تقسيط: فواتير آجلة (عليها متبقٍّ) على عميل مسجّل وبدون خطة ──
  const plannedOrderIds = useMemo(() => new Set(installmentPlans.map((p) => p.order_id)), [installmentPlans]);
  const deferredInvoices = useMemo(() => orders.filter((o: any) =>
    o.type === 'sale' && !o.is_deleted &&
    ((Number(o.total) || 0) - (Number(o.paid_amount) || 0)) > 0.01 &&
    (o.customer?.id || o.customer_id) &&
    !plannedOrderIds.has(o.id)
  ), [orders, plannedOrderIds]);

  const [selInvoice, setSelInvoice] = useState('');
  const [count, setCount] = useState('4');
  const [intervalType, setIntervalType] = useState<'monthly' | 'quarterly' | 'custom'>('monthly');
  const [intervalDays, setIntervalDays] = useState('30');
  const [interestType, setInterestType] = useState<'none' | 'percent' | 'fixed'>('none');
  const [interestValue, setInterestValue] = useState('');
  const [firstDue, setFirstDue] = useState('');
  const [note, setNote] = useState('');

  const selInv: any = orders.find((o: any) => o.id === selInvoice);
  const financed = selInv ? Math.max(0, (Number(selInv.total) || 0) - (Number(selInv.paid_amount) || 0)) : 0;
  const interestAmt = interestType === 'percent' ? financed * (parseFloat(interestValue) || 0) / 100 : interestType === 'fixed' ? (parseFloat(interestValue) || 0) : 0;
  const totalDue = financed + interestAmt;
  const nCount = Math.max(1, parseInt(count) || 1);
  const perInst = totalDue / nCount;

  const handleCreate = async () => {
    if (!selInvoice) return alert('اختاري الفاتورة الآجلة');
    if (nCount < 1) return alert('عدد الدفعات غير صحيح');
    setBusy(true);
    const ok = await createInstallmentPlan(selInvoice, {
      installments_count: nCount,
      interval_type: intervalType,
      interval_days: intervalType === 'custom' ? Math.max(1, parseInt(intervalDays) || 30) : undefined,
      interest_type: interestType,
      interest_value: parseFloat(interestValue) || 0,
      first_due_date: firstDue || undefined,
      note: note || undefined,
    });
    setBusy(false);
    if (ok) {
      alert('تم إنشاء خطة التقسيط ✅');
      setSelInvoice(''); setInterestValue(''); setNote(''); setFirstDue('');
      setTab('collect');
    }
  };

  const card = 'bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700';
  const input = 'w-full bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2.5 text-sm font-bold text-slate-800 dark:text-slate-100 focus:ring-2 focus:ring-indigo-500 outline-none';

  return (
    <div className="p-6 md:p-8 space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-3xl font-black text-slate-800 dark:text-white flex items-center gap-3"><CalendarClock className="text-indigo-600" size={30} /> الأقساط والتحصيل</h1>
          <p className="text-slate-500 mt-1 font-medium text-sm">تقسيط فواتير العملاء على دفعات + تحصيل الأقساط + تذكير تلقائي قبل الاستحقاق بيومين.</p>
        </div>
      </div>

      {/* ملخّص */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className={`${card} p-4`}>
          <div className="text-[11px] font-bold text-slate-500 flex items-center gap-1"><Wallet size={13} /> إجمالي المتبقّي للتحصيل</div>
          <div className="text-2xl font-black text-indigo-600 mt-1">{totalOutstanding.toFixed(2)}</div>
        </div>
        <div className={`${card} p-4`}>
          <div className="text-[11px] font-bold text-slate-500 flex items-center gap-1"><AlertTriangle size={13} /> متأخّرات</div>
          <div className="text-2xl font-black text-red-600 mt-1">{overdueTotal.toFixed(2)}</div>
          <div className="text-[10px] text-slate-400">{overdue.length} قسط متأخّر</div>
        </div>
        <div className={`${card} p-4`}>
          <div className="text-[11px] font-bold text-slate-500 flex items-center gap-1"><Clock size={13} /> مستحق هذا الشهر</div>
          <div className="text-2xl font-black text-amber-600 mt-1">{dueThisMonthTotal.toFixed(2)}</div>
        </div>
        <div className={`${card} p-4`}>
          <div className="text-[11px] font-bold text-slate-500 flex items-center gap-1"><CalendarClock size={13} /> خطط نشطة</div>
          <div className="text-2xl font-black text-slate-800 dark:text-white mt-1">{activePlansCount}</div>
        </div>
      </div>

      {/* تبويبات */}
      <div className="flex gap-2">
        <button onClick={() => setTab('collect')} className={`px-5 py-2.5 rounded-xl font-black text-sm ${tab === 'collect' ? 'bg-indigo-600 text-white' : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300'}`}>التحصيلات</button>
        <button onClick={() => setTab('create')} className={`px-5 py-2.5 rounded-xl font-black text-sm flex items-center gap-1.5 ${tab === 'create' ? 'bg-indigo-600 text-white' : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300'}`}><Plus size={15} /> إنشاء تقسيط</button>
      </div>

      {tab === 'collect' && (
        <div className="space-y-4">
          {plansView.length === 0 && <div className={`${card} p-10 text-center text-slate-400 font-bold`}>لا توجد خطط تقسيط بعد. أنشئي خطة من تبويب «إنشاء تقسيط».</div>}
          {plansView.map(({ p, insts, paidCount, remaining }) => (
            <div key={p.id} className={`${card} overflow-hidden`}>
              <div className="flex flex-wrap items-center justify-between gap-2 p-4 bg-slate-50 dark:bg-slate-900/40 border-b border-slate-200 dark:border-slate-700">
                <div>
                  <div className="font-black text-slate-800 dark:text-white flex items-center gap-2">
                    {custName(p.customer_id)}
                    {p.status === 'completed' && <span className="text-[10px] font-bold text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-full">مكتملة</span>}
                  </div>
                  <div className="text-[11px] text-slate-500 flex items-center gap-1"><Receipt size={12} /> فاتورة #{p.order_id} · {custPhone(p.customer_id)}</div>
                </div>
                <div className="flex gap-4 text-center">
                  <div><div className="text-[10px] text-slate-400 font-bold">إجمالي التقسيط</div><div className="font-black text-slate-700 dark:text-slate-200">{(Number(p.total_due) || 0).toFixed(0)} {cur}</div></div>
                  {(Number(p.interest_amount) || 0) > 0 && <div><div className="text-[10px] text-slate-400 font-bold">الفايدة</div><div className="font-black text-purple-600">{(Number(p.interest_amount) || 0).toFixed(0)}</div></div>}
                  <div><div className="text-[10px] text-slate-400 font-bold">متبقّي</div><div className="font-black text-indigo-600">{remaining.toFixed(0)} {cur}</div></div>
                  <div><div className="text-[10px] text-slate-400 font-bold">مدفوع</div><div className="font-black text-emerald-600">{paidCount}/{insts.length}</div></div>
                </div>
              </div>
              <div className="divide-y divide-slate-100 dark:divide-slate-700/50">
                {insts.map((inst) => {
                  const st = statusOf(inst.due_date, inst.paid);
                  return (
                    <div key={inst.id} className="flex flex-wrap items-center justify-between gap-2 p-3 px-4">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-slate-100 dark:bg-slate-700 flex items-center justify-center text-xs font-black text-slate-600 dark:text-slate-300">{inst.seq}</div>
                        <div>
                          <div className="font-black text-slate-800 dark:text-slate-100">{(Number(inst.amount) || 0).toFixed(2)} {cur}</div>
                          <div className="text-[11px] text-slate-500">استحقاق: {inst.due_date}</div>
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        <span className={`text-[11px] font-black px-2.5 py-1 rounded-lg ${st.cls}`}>{st.label}</span>
                        {!inst.paid ? (
                          <>
                            <button
                              onClick={() => onReminderClick(inst, insts)}
                              title={st.key === 'overdue' ? 'تذكير واتساب (قسط متأخّر — مع ملاحظة/غرامة)' : 'إرسال تذكير واتساب للعميل'}
                              className={`p-1.5 rounded-lg transition ${st.key === 'overdue' ? 'bg-red-100 text-red-600 hover:bg-red-200' : 'bg-emerald-50 text-emerald-600 hover:bg-emerald-100'}`}
                            >
                              <MessageCircle size={16} />
                            </button>
                            <select value={collectMethod[inst.id] || 'cash'} onChange={(e) => setCollectMethod((m) => ({ ...m, [inst.id]: e.target.value }))} className="bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-600 rounded-lg px-2 py-1.5 text-xs font-bold">
                              {payKeys.map((k) => <option key={k} value={k}>{payLabelOf(storeSettings as any, k)}</option>)}
                            </select>
                            <button disabled={busy} onClick={() => handleCollect(inst)} className="bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 text-white text-xs font-black px-4 py-1.5 rounded-lg">تحصيل</button>
                          </>
                        ) : (
                          <span className="text-emerald-600 flex items-center gap-1 text-xs font-bold"><CheckCircle2 size={15} /> {inst.paid_at ? new Date(inst.paid_at).toLocaleDateString('ar-EG') : ''}</span>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      )}

      {tab === 'create' && (
        <div className={`${card} p-5 max-w-2xl space-y-4`}>
          <div>
            <label className="text-xs font-bold text-slate-500 block mb-1">الفاتورة الآجلة (على عميل مسجّل)</label>
            <select value={selInvoice} onChange={(e) => setSelInvoice(e.target.value)} className={input}>
              <option value="">— اختاري فاتورة عليها متبقٍّ —</option>
              {deferredInvoices.map((o: any) => {
                const cid = o.customer?.id || o.customer_id;
                const rem = (Number(o.total) || 0) - (Number(o.paid_amount) || 0);
                return <option key={o.id} value={o.id}>#{o.id} · {custName(cid)} · متبقّي {rem.toFixed(0)} {cur}</option>;
              })}
            </select>
            {deferredInvoices.length === 0 && <p className="text-[11px] text-slate-400 mt-1">لا توجد فواتير آجلة متاحة للتقسيط (لازم تكون على عميل مسجّل وعليها متبقٍّ ومش متقسّطة).</p>}
          </div>

          {selInv && (
            <>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-bold text-slate-500 block mb-1">عدد الدفعات</label>
                  <input type="number" min="1" className={input} value={count} onChange={(e) => setCount(e.target.value)} />
                </div>
                <div>
                  <label className="text-xs font-bold text-slate-500 block mb-1">فترة التقسيط</label>
                  <select className={input} value={intervalType} onChange={(e) => setIntervalType(e.target.value as any)}>
                    <option value="monthly">شهري</option>
                    <option value="quarterly">ربع سنوي (كل 3 شهور)</option>
                    <option value="custom">مخصص (عدد أيام)</option>
                  </select>
                </div>
                {intervalType === 'custom' && (
                  <div>
                    <label className="text-xs font-bold text-slate-500 block mb-1">عدد الأيام بين كل دفعة</label>
                    <input type="number" min="1" className={input} value={intervalDays} onChange={(e) => setIntervalDays(e.target.value)} />
                  </div>
                )}
                <div>
                  <label className="text-xs font-bold text-slate-500 block mb-1">تاريخ أول قسط <span className="text-slate-400 font-normal">(اختياري)</span></label>
                  <input type="date" className={input} value={firstDue} onChange={(e) => setFirstDue(e.target.value)} />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-bold text-slate-500 block mb-1">فايدة التقسيط</label>
                  <select className={input} value={interestType} onChange={(e) => setInterestType(e.target.value as any)}>
                    <option value="none">بدون فايدة</option>
                    <option value="percent">نسبة % على المبلغ المموّل</option>
                    <option value="fixed">مبلغ ثابت</option>
                  </select>
                </div>
                {interestType !== 'none' && (
                  <div>
                    <label className="text-xs font-bold text-slate-500 block mb-1">{interestType === 'percent' ? 'النسبة %' : `المبلغ (${cur})`}</label>
                    <input type="number" min="0" step="0.01" className={input} value={interestValue} onChange={(e) => setInterestValue(e.target.value)} placeholder={interestType === 'percent' ? 'مثلاً 10' : '0.00'} />
                  </div>
                )}
              </div>

              <input className={input} placeholder="ملاحظة (اختياري)" value={note} onChange={(e) => setNote(e.target.value)} />

              {/* معاينة */}
              <div className="bg-indigo-50 dark:bg-indigo-900/20 rounded-xl p-4 space-y-1 text-sm">
                <div className="flex justify-between"><span className="text-slate-500 font-bold">المبلغ المموّل (المتبقّي):</span><span className="font-black">{financed.toFixed(2)} {cur}</span></div>
                {interestAmt > 0 && <div className="flex justify-between"><span className="text-slate-500 font-bold">الفايدة:</span><span className="font-black text-purple-600">+{interestAmt.toFixed(2)} {cur}</span></div>}
                <div className="flex justify-between border-t border-indigo-200 dark:border-indigo-800 pt-1"><span className="text-slate-600 font-black">الإجمالي بعد الفايدة:</span><span className="font-black text-indigo-700">{totalDue.toFixed(2)} {cur}</span></div>
                <div className="flex justify-between"><span className="text-slate-500 font-bold">قيمة كل قسط ({nCount} دفعات):</span><span className="font-black">{perInst.toFixed(2)} {cur}</span></div>
              </div>

              <button disabled={busy} onClick={handleCreate} className="w-full bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white font-black py-3 rounded-xl">{busy ? 'جاري...' : 'إنشاء خطة التقسيط'}</button>
            </>
          )}
        </div>
      )}

      {/* بوب أب تذكير القسط المتأخّر (مع ملاحظة/غرامة) */}
      {noteModal && (
        <div className="fixed inset-0 z-[160] flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm" onClick={() => setNoteModal(null)}>
          <div className="bg-white dark:bg-slate-800 rounded-3xl shadow-2xl w-full max-w-md overflow-hidden" onClick={(e) => e.stopPropagation()}>
            <div className="p-5 border-b border-gray-100 dark:border-slate-700 flex justify-between items-center bg-red-50 dark:bg-red-900/20">
              <h2 className="font-black text-lg flex items-center gap-2 text-red-600"><AlertTriangle size={20} /> قسط متأخّر — تذكير واتساب</h2>
              <button onClick={() => setNoteModal(null)} className="hover:bg-slate-200 dark:hover:bg-slate-700 p-1.5 rounded-lg"><X size={20} /></button>
            </div>
            <div className="p-5 space-y-3">
              <div className="text-sm">
                <div className="font-black text-slate-800 dark:text-white">{custName(noteModal.inst.customer_id)}</div>
                <div className="text-slate-500 text-[13px]">القسط رقم {noteModal.inst.seq} · {(Number(noteModal.inst.amount) || 0).toFixed(2)} {cur} · استحقاق {noteModal.inst.due_date}</div>
                <div className="text-red-600 font-bold text-[13px] mt-1">⚠️ متأخّر {Math.abs(daysUntil(noteModal.inst.due_date))} يوم</div>
              </div>
              <div>
                <label className="text-xs font-bold text-slate-500 block mb-1">ملاحظة تُضاف للرسالة (اختياري — مثلاً غرامة تأخير)</label>
                <textarea value={noteModal.note} onChange={(e) => setNoteModal({ ...noteModal, note: e.target.value })} rows={3} placeholder="مثلاً: نظراً للتأخّر يُضاف غرامة تأخير 50 ج.م على القسط، برجاء السداد سريعاً." className="w-full bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-600 rounded-xl px-3 py-2.5 text-sm outline-none focus:ring-2 focus:ring-red-300 resize-none" />
              </div>
              <button onClick={() => { sendReminder(noteModal.inst, noteModal.insts, noteModal.note); setNoteModal(null); }} className="w-full bg-emerald-600 hover:bg-emerald-700 text-white font-black py-3 rounded-xl flex items-center justify-center gap-2">
                <MessageCircle size={18} /> إرسال التذكير على واتساب
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
