import { useMemo, useState } from 'react';
import { useStore } from '../../store/useStore';
import { FileText, Printer, Trash2, Search, Building2, Phone, Calendar, MessageCircle, Download } from 'lucide-react';
import { printQuotation, quotationToPdf, sendQuotationWhatsApp } from '../../utils/printQuotation';
import { normalizeArabic } from '../../utils/textUtils';

export default function Quotations() {
  const { quotations, deleteQuotation, storeSettings } = useStore();
  const cur = storeSettings.currency;
  const [q, setQ] = useState('');
  const [sendingId, setSendingId] = useState<string | null>(null);

  const sendWhatsApp = async (x: any) => {
    if (sendingId) return;
    setSendingId(x.id);
    try {
      await sendQuotationWhatsApp(x as any, storeSettings as any);
    } finally {
      setSendingId(null);
    }
  };

  const list = useMemo(() => {
    const term = normalizeArabic(q.trim());
    if (!term) return quotations;
    return quotations.filter((x) =>
      normalizeArabic(x.recipient_company || '').includes(term) ||
      (x.quotation_number || '').includes(q.trim()) ||
      (x.recipient_phone || '').includes(q.trim())
    );
  }, [quotations, q]);

  const totalValue = quotations.reduce((s, x) => s + (Number(x.total) || 0), 0);

  const reprint = (x: any) => printQuotation(x, storeSettings as any);
  const remove = async (x: any) => {
    if (!window.confirm(`حذف عرض السعر ${x.quotation_number} نهائياً؟`)) return;
    await deleteQuotation(x.id);
  };

  return (
    <div className="p-6 md:p-8 space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-3xl font-black text-slate-800 dark:text-white flex items-center gap-3"><FileText className="text-purple-600" size={30} /> عروض الأسعار</h1>
          <p className="text-slate-500 mt-1 font-medium text-sm">كل عروض الأسعار المحفوظة — تقدري تعيدي طباعتها A4 في أي وقت.</p>
        </div>
        <div className="flex gap-3">
          <div className="bg-white dark:bg-slate-800 rounded-2xl px-5 py-3 text-center border border-slate-200 dark:border-slate-700">
            <div className="text-[11px] font-bold text-slate-500">عدد العروض</div>
            <div className="text-2xl font-black text-purple-600">{quotations.length}</div>
          </div>
          <div className="bg-gradient-to-l from-purple-600 to-indigo-600 text-white rounded-2xl px-5 py-3 text-center">
            <div className="text-[11px] font-bold opacity-90">إجمالي قيمة العروض</div>
            <div className="text-2xl font-black">{totalValue.toLocaleString()} {cur}</div>
          </div>
        </div>
      </div>

      <div className="relative max-w-md">
        <Search size={18} className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400" />
        <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="بحث باسم الشركة / رقم العرض / الهاتف..." className="w-full bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-2xl pr-10 pl-4 py-3 font-bold text-sm outline-none focus:ring-2 focus:ring-purple-400" />
      </div>

      {list.length === 0 ? (
        <div className="bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 p-12 text-center text-slate-400 font-bold">
          {quotations.length === 0 ? 'لا توجد عروض أسعار بعد. أنشئي عرض من شاشة الكاشير (زر «إنشاء عرض سعر»).' : 'لا نتائج مطابقة للبحث.'}
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {list.map((x) => (
            <div key={x.id} className="bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 overflow-hidden flex flex-col">
              <div className="p-4 bg-slate-50 dark:bg-slate-900/40 border-b border-slate-100 dark:border-slate-700">
                <div className="flex items-center justify-between">
                  <span className="text-[11px] font-black text-purple-600 bg-purple-50 dark:bg-purple-900/30 px-2 py-0.5 rounded-lg">{x.quotation_number}</span>
                  <span className="text-[11px] text-slate-400 flex items-center gap-1"><Calendar size={12} /> {new Date(x.created_at || Date.now()).toLocaleDateString('ar-EG')}</span>
                </div>
                <div className="font-black text-slate-800 dark:text-white mt-2 flex items-center gap-1.5"><Building2 size={15} className="text-slate-400" /> {x.recipient_company || '—'}</div>
                {x.recipient_phone && <div className="text-[12px] text-slate-500 flex items-center gap-1.5 mt-0.5"><Phone size={12} /> {x.recipient_phone}</div>}
              </div>
              <div className="p-4 flex-1">
                <div className="text-[12px] text-slate-500 mb-2">{(x.items || []).length} بند{x.execution_period ? ` · مدة التنفيذ: ${x.execution_period}` : ''}</div>
                <div className="text-2xl font-black text-slate-800 dark:text-white">{(Number(x.total) || 0).toLocaleString()} <span className="text-sm font-bold text-slate-400">{cur}</span></div>
              </div>
              <div className="p-3 border-t border-slate-100 dark:border-slate-700 space-y-2">
                <button
                  onClick={() => sendWhatsApp(x)}
                  disabled={!x.recipient_phone || sendingId === x.id}
                  className="w-full bg-emerald-500 hover:bg-emerald-600 disabled:opacity-40 disabled:cursor-not-allowed text-white font-black py-2.5 rounded-xl flex items-center justify-center gap-2 text-sm"
                  title={x.recipient_phone ? 'إرسال العرض (PDF) للعميل على واتساب' : 'لا يوجد رقم هاتف للعميل'}
                >
                  <MessageCircle size={16} /> {sendingId === x.id ? 'جارٍ تجهيز الـ PDF…' : 'إرسال / تواصل واتساب'}
                </button>
                <div className="flex gap-2">
                  <button onClick={() => reprint(x)} className="flex-1 bg-purple-600 hover:bg-purple-700 text-white font-bold py-2.5 rounded-xl flex items-center justify-center gap-1.5 text-sm"><Printer size={15} /> طباعة</button>
                  <button onClick={() => quotationToPdf(x as any, storeSettings as any)} className="flex-1 bg-slate-700 hover:bg-slate-800 text-white font-bold py-2.5 rounded-xl flex items-center justify-center gap-1.5 text-sm"><Download size={15} /> PDF</button>
                  <button onClick={() => remove(x)} className="bg-red-50 dark:bg-red-900/20 text-red-500 hover:bg-red-100 px-3 rounded-xl"><Trash2 size={16} /></button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
