import QRCode from 'qrcode';
import jsPDF from 'jspdf';
import html2canvas from 'html2canvas-pro';
import { escapeHtml } from './escapeHtml';
import { openPrintWindow } from './printWindow';
import { waLink } from './waPhone';
import { supabase } from '../lib/supabase';

export interface QuotationPrintData {
  quotation_number: string;
  recipient_company?: string;
  recipient_phone?: string;
  intro_text?: string;
  notes?: string;
  execution_period?: string;
  items: { name: string; quantity: number; unit_price: number; total: number }[];
  subtotal: number;
  discount: number;
  total: number;
  cashier_name?: string;
  created_at?: string;
}

interface CompanyLike {
  name?: string; logo?: string; phone?: string; phone2?: string; address?: string;
  currency?: string; themeColor?: string; whatsappCountryCode?: string;
}

const money = (n: number, cur: string) => `${(Number(n) || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${cur}`;
const fmtDate = (q: QuotationPrintData) => new Date(q.created_at || Date.now()).toLocaleDateString('ar-EG', { year: 'numeric', month: 'long', day: 'numeric' });

// نص الـ QR = ملخّص تفاصيل العرض.
function qrTextOf(q: QuotationPrintData, settings: CompanyLike): string {
  const cur = settings.currency || 'ج.م';
  return `عرض سعر: ${q.quotation_number}\nمن: ${settings.name || ''}\n` +
    (q.recipient_company ? `إلى: ${q.recipient_company}\n` : '') +
    `التاريخ: ${fmtDate(q)}\nالإجمالي: ${money(q.total, cur)}\nعدد البنود: ${q.items.length}\n` +
    q.items.slice(0, 12).map((it) => `• ${it.name} ×${it.quantity} = ${money(it.total, cur)}`).join('\n') +
    (q.execution_period ? `\nمدة التنفيذ: ${q.execution_period}` : '');
}

async function qrDataUrl(text: string): Promise<string> {
  try { return await QRCode.toDataURL(text, { width: 240, margin: 0, errorCorrectionLevel: 'M' }); }
  catch { return ''; }
}

// محتوى العرض (style + .page) — يُعاد استخدامه للطباعة والـ PDF.
function quotationInner(q: QuotationPrintData, settings: CompanyLike, qrSrc: string): string {
  const cur = settings.currency || 'ج.م';
  const accent = settings.themeColor || '#4f46e5';
  const dateStr = fmtDate(q);
  const m = (n: number) => money(n, cur);
  const contact = [settings.phone, settings.phone2].filter(Boolean).join(' • ');
  const intro = q.intro_text || `تحية طيبة وبعد،،\nيسعد ${settings.name || 'شركتنا'} أن تتقدّم لسيادتكم بعرض السعر التالي، آملين أن ينال ثقتكم ورضاكم.`;
  const rows = q.items.map((it, i) => `
    <tr><td class="c">${i + 1}</td><td class="name">${escapeHtml(it.name)}</td>
    <td class="c">${Number(it.quantity) || 0}</td><td class="c">${m(it.unit_price)}</td><td class="c strong">${m(it.total)}</td></tr>`).join('');

  return `<style>
  .qwrap * { margin:0; padding:0; box-sizing:border-box; -webkit-print-color-adjust:exact; print-color-adjust:exact; }
  .qwrap { font-family:'Tajawal','Cairo',sans-serif; color:#1e293b; background:#fff; }
  .page { width:210mm; min-height:297mm; padding:14mm 14mm 12mm; margin:0 auto; position:relative; display:flex; flex-direction:column; background:#fff; }
  .bar { height:6px; background:${accent}; border-radius:4px; }
  .head { display:flex; justify-content:space-between; align-items:flex-start; gap:16px; margin:14px 0 10px; }
  .brand { display:flex; align-items:center; gap:14px; }
  .logo { width:74px; height:74px; object-fit:contain; border-radius:14px; border:1px solid #eef; padding:4px; background:#fff; }
  .cname { font-size:26px; font-weight:800; color:#0f172a; }
  .cmeta { font-size:12px; color:#64748b; margin-top:3px; line-height:1.8; }
  .qtitle { font-size:30px; font-weight:800; color:${accent}; text-align:left; }
  .qnum { font-size:13px; font-weight:700; color:#334155; margin-top:4px; text-align:left; }
  .qdate { font-size:12px; color:#64748b; margin-top:2px; text-align:left; }
  .card { background:#f8fafc; border:1px solid #eef2f7; border-radius:14px; padding:12px 16px; margin-top:12px; }
  .card .lbl { font-size:11px; font-weight:700; color:#94a3b8; margin-bottom:3px; }
  .card .val { font-size:15px; font-weight:700; color:#0f172a; }
  .intro { white-space:pre-line; font-size:13.5px; line-height:2; color:#334155; border-right:4px solid ${accent}; padding:6px 14px; margin:12px 0; }
  table { width:100%; border-collapse:collapse; margin-top:6px; }
  thead th { background:${accent}; color:#fff; font-size:13px; font-weight:700; padding:11px 8px; }
  tbody td { padding:10px 8px; font-size:13px; border-bottom:1px solid #eef2f7; }
  tbody tr:nth-child(even) { background:#f8fafc; }
  .name { font-weight:700; color:#0f172a; } .c { text-align:center; } .strong { font-weight:800; color:${accent}; }
  .totals { display:flex; margin-top:12px; }
  .tbox { width:46%; }
  .trow { display:flex; justify-content:space-between; padding:7px 12px; font-size:13px; }
  .trow.grand { background:${accent}; color:#fff; border-radius:12px; font-size:17px; font-weight:800; margin-top:4px; padding:12px 14px; }
  .meta { display:flex; gap:12px; margin-top:14px; } .meta .card { flex:1; margin-top:0; } .meta .val.small { font-size:13px; font-weight:500; line-height:1.9; white-space:pre-line; }
  .foot { margin-top:auto; padding-top:14px; display:flex; justify-content:space-between; align-items:flex-end; gap:16px; }
  .qr { text-align:center; } .qr img { width:96px; height:96px; } .qr .cap { font-size:10px; color:#94a3b8; margin-top:3px; }
  .sign { text-align:center; font-size:12px; color:#475569; } .sign .line { width:150px; border-top:1.5px dashed #cbd5e1; margin:34px auto 6px; }
  .thanks { text-align:center; font-size:12px; color:#64748b; margin-top:12px; }
  .footbar { margin-top:10px; font-size:11px; color:#94a3b8; text-align:center; border-top:1px solid #eef2f7; padding-top:8px; }
  </style>
  <div class="qwrap"><div class="page">
    <div class="bar"></div>
    <div class="head">
      <div class="brand">
        ${settings.logo ? `<img class="logo" src="${escapeHtml(settings.logo)}" crossorigin="anonymous" onerror="this.style.display='none'"/>` : ''}
        <div><div class="cname">${escapeHtml(settings.name || 'شركتنا')}</div>
        <div class="cmeta">${contact ? `📞 ${escapeHtml(contact)}<br/>` : ''}${settings.address ? `📍 ${escapeHtml(settings.address)}` : ''}</div></div>
      </div>
      <div><div class="qtitle">عرض سعر</div><div class="qnum">رقم: ${escapeHtml(q.quotation_number)}</div><div class="qdate">${escapeHtml(dateStr)}</div></div>
    </div>
    <div class="card"><div class="lbl">السادة / المرسل إليهم</div><div class="val">${escapeHtml(q.recipient_company || '—')}</div>
      ${q.recipient_phone ? `<div class="cmeta" style="margin-top:4px">📞 ${escapeHtml(q.recipient_phone)}</div>` : ''}</div>
    <div class="intro">${escapeHtml(intro)}</div>
    <table><thead><tr><th style="width:8%">#</th><th style="width:46%">البيان</th><th style="width:12%">الكمية</th><th style="width:17%">سعر الوحدة</th><th style="width:17%">الإجمالي</th></tr></thead><tbody>${rows}</tbody></table>
    <div class="totals"><div class="tbox">
      <div class="trow"><span>الإجمالي الفرعي</span><span>${m(q.subtotal)}</span></div>
      ${q.discount > 0 ? `<div class="trow"><span>الخصم</span><span>- ${m(q.discount)}</span></div>` : ''}
      <div class="trow grand"><span>الإجمالي النهائي</span><span>${m(q.total)}</span></div>
    </div></div>
    <div class="meta">
      ${q.execution_period ? `<div class="card"><div class="lbl">مدة التنفيذ</div><div class="val small">${escapeHtml(q.execution_period)}</div></div>` : ''}
      ${q.notes ? `<div class="card"><div class="lbl">ملاحظات</div><div class="val small">${escapeHtml(q.notes)}</div></div>` : ''}
    </div>
    <div class="foot">
      <div class="qr">${qrSrc ? `<img src="${qrSrc}"/><div class="cap">امسح للتفاصيل</div>` : ''}</div>
      <div class="sign"><div>مع خالص الشكر والتقدير</div><div class="line"></div><div>التوقيع والختم</div></div>
    </div>
    <div class="thanks">هذا العرض مقدّم من ${escapeHtml(settings.name || 'شركتنا')} — نتشرّف بخدمتكم</div>
    <div class="footbar">${escapeHtml(settings.name || '')}${contact ? ` • ${escapeHtml(contact)}` : ''}${settings.address ? ` • ${escapeHtml(settings.address)}` : ''}</div>
  </div></div>`;
}

export async function printQuotation(q: QuotationPrintData, settings: CompanyLike): Promise<void> {
  const qr = await qrDataUrl(qrTextOf(q, settings));
  const html = `<!DOCTYPE html><html lang="ar" dir="rtl"><head><meta charset="UTF-8"/><title>عرض سعر ${escapeHtml(q.quotation_number)}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Tajawal:wght@400;500;700;800&display=swap" rel="stylesheet">
  <style>@page{size:A4;margin:0;} body{margin:0;}</style></head><body>${quotationInner(q, settings, qr)}
  <script>window.onload=function(){setTimeout(function(){window.print();},450);};</script></body></html>`;
  openPrintWindow(html, 'width=900,height=1200');
}

// يبني ملف الـ PDF (مقاس A4) في الذاكرة ويعيد كائن jsPDF — يُعاد استخدامه للتنزيل والرفع.
async function buildQuotationPdf(q: QuotationPrintData, settings: CompanyLike): Promise<jsPDF> {
  const qr = await qrDataUrl(qrTextOf(q, settings));
  const holder = document.createElement('div');
  holder.style.cssText = 'position:fixed; right:-10000px; top:0; width:210mm; background:#fff; z-index:-1;';
  holder.dir = 'rtl';
  holder.innerHTML = quotationInner(q, settings, qr);
  document.body.appendChild(holder);
  try {
    await new Promise((r) => setTimeout(r, 350)); // انتظار تحميل الخط/الصور
    const el = holder.querySelector('.page') as HTMLElement;
    const canvas = await html2canvas(el, { scale: 2, useCORS: true, logging: false, backgroundColor: '#ffffff' });
    const img = canvas.toDataURL('image/jpeg', 0.92);
    const pdf = new jsPDF('p', 'mm', 'a4');
    const pw = pdf.internal.pageSize.getWidth();
    const ph = pdf.internal.pageSize.getHeight();
    const ih = (canvas.height * pw) / canvas.width;
    let left = ih; let pos = 0;
    pdf.addImage(img, 'JPEG', 0, pos, pw, ih);
    left -= ph;
    while (left > 0) { pos -= ph; pdf.addPage(); pdf.addImage(img, 'JPEG', 0, pos, pw, ih); left -= ph; }
    return pdf;
  } finally {
    holder.remove();
  }
}

// تصدير PDF مقاس A4 (تنزيل على الجهاز).
export async function quotationToPdf(q: QuotationPrintData, settings: CompanyLike): Promise<void> {
  try {
    const pdf = await buildQuotationPdf(q, settings);
    pdf.save(`عرض-سعر-${q.quotation_number}.pdf`);
  } catch (e) {
    console.error('quotationToPdf error:', e);
    alert('تعذّر إنشاء PDF، جرّبي زر الطباعة ثم «حفظ كـ PDF».');
  }
}

// اسم الـ bucket العام في Supabase Storage الذي تُرفع إليه ملفات عروض الأسعار.
const QUOTATIONS_BUCKET = 'quotations';

// يرفع الـ PDF إلى Supabase Storage ويعيد رابط التحميل العام (أو null لو فشل الرفع).
export async function uploadQuotationPdf(q: QuotationPrintData, settings: CompanyLike): Promise<string | null> {
  try {
    const pdf = await buildQuotationPdf(q, settings);
    const blob = pdf.output('blob') as Blob;
    // مفتاح آمن (حروف/أرقام فقط) لتفادي مشاكل الترميز في مسار التخزين.
    const safeNum = String(q.quotation_number || 'quote').replace(/[^\w-]+/g, '-');
    const path = `${safeNum}.pdf`;
    const { error } = await supabase.storage
      .from(QUOTATIONS_BUCKET)
      .upload(path, blob, { contentType: 'application/pdf', upsert: true });
    if (error) { console.error('uploadQuotationPdf error:', error); return null; }
    const { data } = supabase.storage.from(QUOTATIONS_BUCKET).getPublicUrl(path);
    return data?.publicUrl || null;
  } catch (e) {
    console.error('uploadQuotationPdf exception:', e);
    return null;
  }
}

// نص واتساب (فاتورة إلكترونية) + فتح المحادثة مع العميل.
// pdfUrl (اختياري): رابط تحميل ملف الـ PDF يُضاف في نهاية الرسالة.
export function quotationWhatsAppText(q: QuotationPrintData, settings: CompanyLike, pdfUrl?: string | null): string {
  const cur = settings.currency || 'ج.م';
  const m = (n: number) => money(n, cur);
  const items = q.items.map((it) => `• ${it.name} × ${it.quantity} = ${m(it.total)}`).join('\n');
  return `🧾 *عرض سعر* من ${settings.name || 'شركتنا'}\n` +
    `رقم: ${q.quotation_number}\nالتاريخ: ${fmtDate(q)}\n` +
    (q.recipient_company ? `إلى: *${q.recipient_company}*\n` : '') +
    `\n*الأصناف:*\n${items}\n\n*الإجمالي: ${m(q.total)}*` +
    (q.execution_period ? `\nمدة التنفيذ: ${q.execution_period}` : '') +
    (q.notes ? `\nملاحظات: ${q.notes}` : '') +
    (pdfUrl ? `\n\n📄 *عرض السعر PDF:*\n${pdfUrl}` : '') +
    `\n\nفي انتظار ردكم، ونسعد بخدمتكم 🌟\n${settings.name || ''}${settings.phone ? ` — ${settings.phone}` : ''}`;
}

// يُنشئ الـ PDF ويرفعه على التخزين ثم يفتح واتساب العميل برسالة تحوي رابط تحميل الملف.
// لو فشل الرفع، يرجع لإرسال الرسالة النصية فقط حتى لا تتعطّل العملية.
export async function sendQuotationWhatsApp(q: QuotationPrintData, settings: CompanyLike): Promise<void> {
  const cc = settings.whatsappCountryCode || '20';
  // نتحقق من صلاحية الرقم أولاً قبل بذل مجهود إنشاء/رفع الـ PDF.
  const preflight = waLink(q.recipient_phone, 'x', cc);
  if (!preflight) { alert('رقم هاتف العميل غير صالح أو غير موجود في هذا العرض.'); return; }

  // نفتح تبويباً فارغاً الآن (أثناء ضغطة المستخدم) لتفادي حظر النوافذ المنبثقة بعد الـ await.
  const win = window.open('about:blank', '_blank');

  const pdfUrl = await uploadQuotationPdf(q, settings);
  if (!pdfUrl) {
    // فشل الرفع (غالباً bucket «quotations» غير موجود) — نكمل بالنص فقط.
    console.warn('WhatsApp: PDF upload failed, sending text only.');
  }
  const link = waLink(q.recipient_phone, quotationWhatsAppText(q, settings, pdfUrl), cc);
  if (!link) { if (win) win.close(); alert('رقم هاتف العميل غير صالح أو غير موجود في هذا العرض.'); return; }
  if (win) win.location.href = link;   // إعادة توجيه التبويب المفتوح مسبقاً
  else window.open(link, '_blank');     // احتياطي لو تعذّر فتح التبويب المسبق
}
