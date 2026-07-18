// ============================================================================
// مبيعات اليوم — /admin/daily-sales
// ============================================================================
// شاشة الأدمن اليومية: يشوف مبيعات يوم واحد، وجنب كل صنف اسم الموظف المسؤول،
// ويكتب عمولة كل منتج (قيمة بالجنيه للقطعة) ويأكّدها. العمولات المؤكَّدة
// بتتجمّع في بروفايل الموظف وبتظهر وهو بياخد راتبه.
//
// الخدمات عمولتها تلقائية بنسبة % من الإعدادات — بتتعرض للعلم بس، مفيش إدخال.
// ============================================================================
import { useState, useMemo } from 'react';
import { useStore, DEFAULT_SERVICE_COMMISSION_RATE } from '../../store/useStore';
import {
  CalendarDays, Package, Scissors, Check, Edit3, Users, TrendingUp, Search,
} from 'lucide-react';
import {
  localDayKey, ordersOnDay, netQuantity, netLineTotal,
  serviceCommissionFor, productCommissionFor, isServiceItem,
} from '../../utils/commissions';

interface SaleLine {
  // null = الصنف اتحمّل من غير id صف order_items (فاتورة أوفلاين لسه ما اتزامنتش).
  // ساعتها مينفعش نعدّل عمولته — أي id مخترع هيروح على صف تاني أو يرمي خطأ.
  orderItemId: string | null;
  rowKey: string;
  orderId: string;
  productName: string;
  isService: boolean;
  qty: number;
  salePrice: number;
  lineTotal: number;
  salespersonId: string | null;
  salespersonName: string | null;
  commissionPerUnit: number;
  commissionTotal: number;
  confirmed: boolean;
  time: string;
}

export default function DailySales() {
  const { orders, employees, storeSettings, updateItemCommission, updateItemSalesperson } = useStore();
  const tc = storeSettings.themeColor;
  const cur = storeSettings.currency;
  const serviceRate = storeSettings.serviceCommissionRate ?? DEFAULT_SERVICE_COMMISSION_RATE;

  const [day, setDay] = useState<string>(localDayKey(new Date()));
  const [search, setSearch] = useState('');
  const [employeeFilter, setEmployeeFilter] = useState<string>('all');
  // مسوّدات الإدخال قبل التأكيد — مفتاحها order_item_id
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const [savingId, setSavingId] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);

  const activeEmployees = useMemo(() => employees.filter((e) => e.is_active !== false), [employees]);

  // كل أسطر البيع في اليوم المختار
  const lines = useMemo<SaleLine[]>(() => {
    const dayOrders = ordersOnDay(orders, day);
    const out: SaleLine[] = [];
    for (const o of dayOrders) {
      (o.items || []).forEach((it, idx) => {
        const qty = netQuantity(it);
        if (qty <= 0) return; // اترجّع بالكامل
        const service = isServiceItem(it);
        const perUnit = Number(it.commission_amount) || 0;
        out.push({
          orderItemId: it.order_item_id || null,
          // مفتاح عرض فريد لكل سطر: نفس المنتج ممكن يتكرر في الفاتورة
          // بموظفين مختلفين، فمفتاح بالمنتج بيخلي الصفين يشاركوا نفس الإدخال.
          rowKey: it.order_item_id || `${o.id}#${idx}`,
          orderId: o.id,
          productName: it.name,
          isService: service,
          qty,
          salePrice: Number(it.sale_price) || 0,
          lineTotal: netLineTotal(it),
          salespersonId: it.salesperson_id ?? null,
          salespersonName: it.salesperson_name ?? null,
          commissionPerUnit: perUnit,
          commissionTotal: service ? serviceCommissionFor(it, serviceRate) : productCommissionFor(it),
          confirmed: service ? true : Boolean(it.commission_confirmed),
          time: new Date(o.date).toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' }),
        });
      });
    }
    return out;
  }, [orders, day, serviceRate]);

  const visibleLines = useMemo(() => {
    const q = search.trim().toLowerCase();
    return lines.filter((l) => {
      const matchesSearch = !q
        || l.productName.toLowerCase().includes(q)
        || (l.salespersonName || '').toLowerCase().includes(q)
        || l.orderId.toLowerCase().includes(q);
      const matchesEmp = employeeFilter === 'all'
        || (employeeFilter === 'none' ? !l.salespersonId : l.salespersonId === employeeFilter);
      return matchesSearch && matchesEmp;
    });
  }, [lines, search, employeeFilter]);

  const productLines = visibleLines.filter((l) => !l.isService);
  const serviceLines = visibleLines.filter((l) => l.isService);

  // ملخّص اليوم
  const totals = useMemo(() => {
    const t = {
      sales: 0, serviceSales: 0, productSales: 0,
      serviceCommission: 0, productCommission: 0,
      pending: 0, unassigned: 0,
    };
    for (const l of lines) {
      t.sales += l.lineTotal;
      if (l.isService) { t.serviceSales += l.lineTotal; t.serviceCommission += l.commissionTotal; }
      else {
        t.productSales += l.lineTotal;
        t.productCommission += l.commissionTotal;
        if (!l.confirmed) t.pending += 1;
      }
      if (!l.salespersonId) t.unassigned += 1;
    }
    return t;
  }, [lines]);

  // العمولات المؤكَّدة في اليوم مجمّعة على الموظف — الجزء اللي تحت الفلتر
  const perEmployee = useMemo(() => {
    const map = new Map<string, { id: string; name: string; sales: number; serviceCom: number; productCom: number; lines: number }>();
    for (const l of lines) {
      if (!l.salespersonId) continue;
      const row = map.get(l.salespersonId) || {
        id: l.salespersonId, name: l.salespersonName || '—',
        sales: 0, serviceCom: 0, productCom: 0, lines: 0,
      };
      row.sales += l.lineTotal;
      row.lines += 1;
      if (l.isService) row.serviceCom += l.commissionTotal;
      else row.productCom += l.commissionTotal;
      map.set(l.salespersonId, row);
    }
    return [...map.values()].sort((a, b) => (b.serviceCom + b.productCom) - (a.serviceCom + a.productCom));
  }, [lines]);

  const draftFor = (l: SaleLine) => drafts[l.rowKey] ?? String(l.commissionPerUnit || '');

  const confirmCommission = async (l: SaleLine) => {
    if (!l.orderItemId) { alert('الفاتورة دي لسه ما اتزامنتش بالكامل — اعمل تحديث للصفحة وحاول تاني.'); return; }
    const value = parseFloat(draftFor(l)) || 0;
    if (value < 0) { alert('العمولة ما تنفعش تكون بالسالب'); return; }
    if (!l.salespersonId) { alert('حدّد الموظف المسؤول عن الصنف ده الأول، وبعدين أكّد العمولة.'); return; }
    setSavingId(l.rowKey);
    const ok = await updateItemCommission(l.orderItemId, value, true);
    setSavingId(null);
    if (ok) {
      setEditingId(null);
      setDrafts((d) => { const next = { ...d }; delete next[l.rowKey]; return next; });
    }
  };

  const unconfirm = async (l: SaleLine) => {
    if (!l.orderItemId) return;
    setSavingId(l.rowKey);
    await updateItemCommission(l.orderItemId, l.commissionPerUnit, false);
    setSavingId(null);
    setEditingId(l.rowKey);
  };

  const changeSalesperson = async (l: SaleLine, empId: string) => {
    const emp = employees.find((e) => e.id === empId);
    if (!emp || !l.orderItemId) return;
    setSavingId(l.rowKey);
    await updateItemSalesperson(l.orderItemId, { id: emp.id, name: emp.name });
    setSavingId(null);
  };

  const shiftDay = (days: number) => {
    const d = new Date(`${day}T00:00:00`);
    d.setDate(d.getDate() + days);
    setDay(localDayKey(d));
  };

  const todayKey = localDayKey(new Date());
  const money = (n: number) => `${Math.round(n).toLocaleString()} ${cur}`;

  return (
    <div className="p-4 md:p-8 space-y-5 animate-fade-in">
      {/* ── الهيدر ── */}
      <div className="flex flex-wrap justify-between items-center gap-4">
        <div>
          <h1 className="text-3xl font-black text-slate-800 flex items-center gap-3">
            <div className="p-2 rounded-2xl text-white shadow-lg" style={{ backgroundColor: tc }}>
              <CalendarDays size={28} />
            </div>
            مبيعات اليوم
          </h1>
          <p className="text-slate-500 mt-2 font-medium">مبيعات كل يوم بالمسؤول عنها — واكتب عمولة كل منتج وأكّدها</p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <button onClick={() => shiftDay(-1)} className="bg-white border border-slate-200 rounded-xl px-3 py-2.5 text-sm font-bold text-slate-600 hover:bg-slate-50">اليوم السابق</button>
          <input
            type="date"
            value={day}
            max={todayKey}
            onChange={(e) => setDay(e.target.value || todayKey)}
            className="bg-white border border-slate-200 rounded-xl px-3 py-2.5 text-sm font-black text-slate-700 outline-none"
          />
          <button onClick={() => shiftDay(1)} disabled={day >= todayKey} className="bg-white border border-slate-200 rounded-xl px-3 py-2.5 text-sm font-bold text-slate-600 hover:bg-slate-50 disabled:opacity-40">اليوم التالي</button>
          <button onClick={() => setDay(todayKey)} className="text-white rounded-xl px-4 py-2.5 text-sm font-black" style={{ backgroundColor: tc }}>النهاردة</button>
        </div>
      </div>

      {/* ── ملخّص اليوم ── */}
      <div className="grid grid-cols-2 lg:grid-cols-5 gap-3">
        <Stat label="إجمالي مبيعات اليوم" value={money(totals.sales)} />
        <Stat label="مبيعات خدمات" value={money(totals.serviceSales)} />
        <Stat label="مبيعات منتجات" value={money(totals.productSales)} />
        <Stat label={`حافز الخدمات (${serviceRate}%)`} value={money(totals.serviceCommission)} green />
        <Stat label="عمولة المنتجات المؤكَّدة" value={money(totals.productCommission)} green />
      </div>

      {(totals.pending > 0 || totals.unassigned > 0) && (
        <div className="flex flex-wrap gap-2">
          {totals.pending > 0 && (
            <div className="text-xs font-black bg-amber-50 text-amber-700 border border-amber-200 rounded-xl px-4 py-2.5">
              ⏳ {totals.pending} منتج لسه ما اتحدّدتش عمولته — اكتب القيمة وأكّد عشان تتحسب للموظف.
            </div>
          )}
          {totals.unassigned > 0 && (
            <div className="text-xs font-black bg-red-50 text-red-700 border border-red-200 rounded-xl px-4 py-2.5">
              ⚠️ {totals.unassigned} صنف من غير موظف مسؤول (فواتير قديمة) — اختار الموظف من الجدول.
            </div>
          )}
        </div>
      )}

      {/* ── فلاتر ── */}
      <div className="flex flex-wrap gap-3 items-end bg-white rounded-2xl border border-slate-200 p-4">
        <div className="relative">
          <Search className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
          <input
            type="text"
            placeholder="بحث بالصنف أو الموظف أو رقم الفاتورة..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="bg-slate-50 border border-slate-200 rounded-xl pr-9 pl-3 py-2.5 text-sm font-bold outline-none w-72"
          />
        </div>
        <select
          value={employeeFilter}
          onChange={(e) => setEmployeeFilter(e.target.value)}
          className="bg-slate-50 border border-slate-200 rounded-xl px-3 py-2.5 text-sm font-bold outline-none"
        >
          <option value="all">كل الموظفين</option>
          <option value="none">بدون مسؤول</option>
          {activeEmployees.map((e) => <option key={e.id} value={e.id}>{e.name}</option>)}
        </select>
        <span className="text-xs font-bold text-slate-400 mr-auto">{visibleLines.length} سطر</span>
      </div>

      {/* ── المنتجات (إدخال العمولة) ── */}
      <div className="bg-white rounded-[24px] shadow-sm border border-slate-100 overflow-hidden">
        <div className="p-5 border-b border-slate-100 bg-slate-50/50 flex items-center gap-2">
          <Package size={20} className="text-slate-400" />
          <h3 className="text-lg font-black text-slate-800">مبيعات المنتجات</h3>
          <span className="text-[11px] font-bold text-slate-400">— اكتب قيمة العمولة للقطعة وأكّد</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-right text-sm">
            <thead className="bg-slate-50 text-slate-500 text-[11px] uppercase tracking-wider">
              <tr>
                <th className="p-3">الصنف</th>
                <th className="p-3">المسؤول</th>
                <th className="p-3">الكمية</th>
                <th className="p-3">القيمة</th>
                <th className="p-3">عمولة القطعة</th>
                <th className="p-3">إجمالي العمولة</th>
                <th className="p-3">الحالة</th>
              </tr>
            </thead>
            <tbody>
              {productLines.length === 0 ? (
                <tr><td colSpan={7} className="text-center text-slate-400 py-10 font-bold">لا توجد مبيعات منتجات في اليوم ده</td></tr>
              ) : productLines.map((l) => {
                const isEditing = editingId === l.rowKey || !l.confirmed;
                const draft = draftFor(l);
                const previewTotal = (parseFloat(draft) || 0) * l.qty;
                const busy = savingId === l.rowKey;
                return (
                  <tr key={l.rowKey} className="border-b border-slate-50 hover:bg-slate-50/50">
                    <td className="p-3">
                      <div className="font-black text-slate-800">{l.productName}</div>
                      <div className="text-[10px] font-bold text-slate-400">#{l.orderId} • {l.time}</div>
                    </td>
                    <td className="p-3">
                      <select
                        value={l.salespersonId || ''}
                        onChange={(e) => changeSalesperson(l, e.target.value)}
                        disabled={busy}
                        className={`border rounded-lg px-2 py-1.5 text-xs font-bold outline-none max-w-[150px] ${
                          l.salespersonId ? 'bg-slate-50 border-slate-200 text-slate-700' : 'bg-red-50 border-red-200 text-red-600'
                        }`}
                      >
                        <option value="" disabled>اختر المسؤول</option>
                        {activeEmployees.map((e) => <option key={e.id} value={e.id}>{e.name}</option>)}
                      </select>
                    </td>
                    <td className="p-3 font-bold text-slate-600">{l.qty}</td>
                    <td className="p-3 font-bold text-slate-600">{money(l.lineTotal)}</td>
                    <td className="p-3">
                      {isEditing ? (
                        <input
                          type="number"
                          min="0"
                          step="0.5"
                          dir="ltr"
                          value={draft}
                          placeholder="0"
                          onChange={(e) => setDrafts((d) => ({ ...d, [l.rowKey]: e.target.value }))}
                          onKeyDown={(e) => { if (e.key === 'Enter') confirmCommission(l); }}
                          className="w-20 bg-white border border-indigo-200 rounded-lg px-2 py-1.5 text-center font-black text-indigo-600 outline-none focus:ring-2 focus:ring-indigo-100"
                        />
                      ) : (
                        <span className="font-black text-slate-700">{l.commissionPerUnit.toFixed(2)}</span>
                      )}
                    </td>
                    <td className="p-3">
                      <span className="font-black text-emerald-600">
                        {(isEditing ? previewTotal : l.commissionTotal).toFixed(2)} <span className="text-[10px] text-slate-400">{cur}</span>
                      </span>
                      {isEditing && l.qty > 1 && (
                        <div className="text-[9px] font-bold text-slate-400">{draft || 0} × {l.qty}</div>
                      )}
                    </td>
                    <td className="p-3">
                      {isEditing ? (
                        <button
                          onClick={() => confirmCommission(l)}
                          disabled={busy}
                          className="flex items-center gap-1 bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 text-white text-xs font-black px-3 py-1.5 rounded-lg"
                        >
                          <Check size={14} /> {busy ? '...' : 'تأكيد'}
                        </button>
                      ) : (
                        <div className="flex items-center gap-1.5">
                          <span className="flex items-center gap-1 bg-emerald-50 text-emerald-600 border border-emerald-100 text-[10px] font-black px-2 py-1 rounded-lg">
                            <Check size={12} /> مؤكَّدة
                          </span>
                          <button onClick={() => unconfirm(l)} disabled={busy} className="text-slate-400 hover:text-indigo-600 p-1" title="تعديل">
                            <Edit3 size={14} />
                          </button>
                        </div>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── الخدمات (عمولة تلقائية) ── */}
      <div className="bg-white rounded-[24px] shadow-sm border border-slate-100 overflow-hidden">
        <div className="p-5 border-b border-slate-100 bg-slate-50/50 flex items-center gap-2">
          <Scissors size={20} className="text-slate-400" />
          <h3 className="text-lg font-black text-slate-800">الخدمات</h3>
          <span className="text-[11px] font-bold text-slate-400">— العمولة تلقائية {serviceRate}% من قيمة الخدمة</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-right text-sm">
            <thead className="bg-slate-50 text-slate-500 text-[11px] uppercase tracking-wider">
              <tr>
                <th className="p-3">الخدمة</th>
                <th className="p-3">المسؤول</th>
                <th className="p-3">العدد</th>
                <th className="p-3">القيمة</th>
                <th className="p-3">العمولة ({serviceRate}%)</th>
              </tr>
            </thead>
            <tbody>
              {serviceLines.length === 0 ? (
                <tr><td colSpan={5} className="text-center text-slate-400 py-10 font-bold">لا توجد خدمات في اليوم ده</td></tr>
              ) : serviceLines.map((l) => (
                <tr key={l.rowKey} className="border-b border-slate-50 hover:bg-slate-50/50">
                  <td className="p-3">
                    <div className="font-black text-slate-800">{l.productName}</div>
                    <div className="text-[10px] font-bold text-slate-400">#{l.orderId} • {l.time}</div>
                  </td>
                  <td className="p-3">
                    <select
                      value={l.salespersonId || ''}
                      onChange={(e) => changeSalesperson(l, e.target.value)}
                      disabled={savingId === l.rowKey}
                      className={`border rounded-lg px-2 py-1.5 text-xs font-bold outline-none max-w-[150px] ${
                        l.salespersonId ? 'bg-slate-50 border-slate-200 text-slate-700' : 'bg-red-50 border-red-200 text-red-600'
                      }`}
                    >
                      <option value="" disabled>اختر المسؤول</option>
                      {activeEmployees.map((e) => <option key={e.id} value={e.id}>{e.name}</option>)}
                    </select>
                  </td>
                  <td className="p-3 font-bold text-slate-600">{l.qty}</td>
                  <td className="p-3 font-bold text-slate-600">{money(l.lineTotal)}</td>
                  <td className="p-3 font-black text-emerald-600">{l.commissionTotal.toFixed(2)} <span className="text-[10px] text-slate-400">{cur}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── عمولات اليوم لكل موظف ── */}
      <div className="bg-white rounded-[24px] shadow-sm border border-slate-100 overflow-hidden">
        <div className="p-5 border-b border-slate-100 bg-slate-50/50 flex items-center gap-2">
          <Users size={20} className="text-slate-400" />
          <h3 className="text-lg font-black text-slate-800">عمولات اليوم لكل موظف</h3>
          <span className="text-[11px] font-bold text-slate-400">— بتتجمّع في بروفايله وبتظهر وهو بياخد راتبه</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-right text-sm">
            <thead className="bg-slate-50 text-slate-500 text-[11px] uppercase tracking-wider">
              <tr>
                <th className="p-3">الموظف</th>
                <th className="p-3">الأصناف</th>
                <th className="p-3">مبيعاته</th>
                <th className="p-3">حافز خدمات</th>
                <th className="p-3">عمولة منتجات</th>
                <th className="p-3">الإجمالي</th>
              </tr>
            </thead>
            <tbody>
              {perEmployee.length === 0 ? (
                <tr><td colSpan={6} className="text-center text-slate-400 py-10 font-bold">لا توجد مبيعات في اليوم ده</td></tr>
              ) : perEmployee.map((r) => (
                <tr key={r.id} className="border-b border-slate-50 hover:bg-slate-50/50">
                  <td className="p-3 font-black text-slate-800">{r.name}</td>
                  <td className="p-3 font-bold text-slate-500">{r.lines}</td>
                  <td className="p-3 font-bold text-slate-600">{money(r.sales)}</td>
                  <td className="p-3 font-bold text-emerald-600">{r.serviceCom.toFixed(2)}</td>
                  <td className="p-3 font-bold text-emerald-600">{r.productCom.toFixed(2)}</td>
                  <td className="p-3">
                    <span className="inline-flex items-center gap-1 bg-emerald-50 text-emerald-700 border border-emerald-100 font-black px-3 py-1.5 rounded-lg">
                      <TrendingUp size={13} /> {(r.serviceCom + r.productCom).toFixed(2)} {cur}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

function Stat({ label, value, green }: { label: string; value: string; green?: boolean }) {
  return (
    <div className="bg-white border border-slate-200 rounded-2xl p-4">
      <div className="text-[11px] font-bold text-slate-500">{label}</div>
      <div className={`text-lg font-black mt-1 ${green ? 'text-emerald-600' : 'text-slate-800'}`}>{value}</div>
    </div>
  );
}
