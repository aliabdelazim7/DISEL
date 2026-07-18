// ============================================================================
// حساب مبيعات وعمولات الموظفين
// ============================================================================
// المصدر الوحيد للحساب — بروفايل الموظف وصفحة مبيعات اليوم وصرف الراتب كلهم
// بينادوا على الدوال دي، عشان الرقم اللي الموظف شايفه هو نفسه اللي بيتصرف.
//
// نوعان من العمولة:
//   • خدمة  → نسبة % من قيمة الخدمة (إعداد عام، افتراضي 10%)
//   • منتج  → قيمة يدوية بالجنيه لكل قطعة، الأدمن بيكتبها ويأكّدها من مبيعات
//             اليوم. من غير تأكيد ما بتتحسبش.
// ============================================================================
import type { Order, OrderItem } from '../store/useStore';

export const isServiceItem = (item: Pick<OrderItem, 'type'>) => item.type === 'service';

/** صافي الكمية بعد المرتجع — المرتجع ما ينفعش يتحسب عمولة. */
export const netQuantity = (item: Pick<OrderItem, 'quantity' | 'returned_quantity'>) =>
  Math.max(0, (Number(item.quantity) || 0) - (Number(item.returned_quantity) || 0));

/** صافي قيمة السطر بعد المرتجع. */
export const netLineTotal = (item: Pick<OrderItem, 'quantity' | 'returned_quantity' | 'sale_price'>) =>
  netQuantity(item) * (Number(item.sale_price) || 0);

/** عمولة سطر خدمة = نسبة % من صافي قيمة الخدمة. */
export const serviceCommissionFor = (
  item: Pick<OrderItem, 'quantity' | 'returned_quantity' | 'sale_price'>,
  rate: number,
) => netLineTotal(item) * (Number(rate) || 0) / 100;

/**
 * عمولة سطر منتج = القيمة اليدوية × صافي الكمية.
 * بترجع صفر لو الأدمن لسه مأكّدش، عشان ما نصرفش أرقام تحت المراجعة.
 */
export const productCommissionFor = (
  item: Pick<OrderItem, 'quantity' | 'returned_quantity' | 'commission_amount' | 'commission_confirmed'>,
) => (item.commission_confirmed ? (Number(item.commission_amount) || 0) * netQuantity(item) : 0);

export interface EmployeeSalesStats {
  serviceSales: number;      // إجمالي مبيعات الخدمات
  productSales: number;      // إجمالي مبيعات المنتجات
  totalSales: number;        // الاتنين مع بعض
  serviceCommission: number; // حافز الخدمات (نسبة %)
  productCommission: number; // عمولة المنتجات (القيم المؤكَّدة)
  totalCommission: number;
  serviceCount: number;      // عدد الخدمات المنفّذة
  pendingProductLines: number; // أسطر منتجات لسه محتاجة تأكيد عمولة
}

export const emptySalesStats = (): EmployeeSalesStats => ({
  serviceSales: 0, productSales: 0, totalSales: 0,
  serviceCommission: 0, productCommission: 0, totalCommission: 0,
  serviceCount: 0, pendingProductLines: 0,
});

/**
 * بيجمع مبيعات وعمولات موظف من الفواتير المعطاة.
 * الفلترة بالتاريخ (شهر / يوم) مسؤولية اللي بينادي — الدالة دي بتجمّع بس.
 */
export function computeEmployeeSales(
  orders: Order[],
  employeeId: string,
  serviceRate: number,
): EmployeeSalesStats {
  const stats = emptySalesStats();

  for (const order of orders) {
    if (order.is_deleted || order.type !== 'sale') continue;

    for (const item of order.items || []) {
      if (item.salesperson_id !== employeeId) continue;

      const lineTotal = netLineTotal(item);
      if (isServiceItem(item)) {
        stats.serviceSales += lineTotal;
        stats.serviceCommission += serviceCommissionFor(item, serviceRate);
        stats.serviceCount += netQuantity(item);
      } else {
        stats.productSales += lineTotal;
        stats.productCommission += productCommissionFor(item);
        if (!item.commission_confirmed && netQuantity(item) > 0) stats.pendingProductLines += 1;
      }
    }
  }

  stats.totalSales = stats.serviceSales + stats.productSales;
  stats.totalCommission = stats.serviceCommission + stats.productCommission;
  return stats;
}

// ── التاريخ ─────────────────────────────────────────────────────────────────
// created_at بيتخزن UTC. لو استخدمنا slice(0,7) هنقرا شهر UTC، فبيعة الساعة
// 1 بالليل يوم 1 أغسطس بتوقيت مصر هتتحسب على يوليو وتروح لعمولة الشهر الغلط.
// الدالتين دول بيرجّعوا اليوم/الشهر بالتوقيت المحلي للمتصفح.

export const localDayKey = (value: string | Date): string => {
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  return [d.getFullYear(), String(d.getMonth() + 1).padStart(2, '0'), String(d.getDate()).padStart(2, '0')].join('-');
};

export const localMonthKey = (value: string | Date): string => localDayKey(value).slice(0, 7);

/** فواتير يوم واحد (YYYY-MM-DD) بالتوقيت المحلي. */
export const ordersOnDay = (orders: Order[], day: string) =>
  orders.filter((o) => !o.is_deleted && o.type === 'sale' && localDayKey(o.date) === day);

/** فواتير شهر واحد (YYYY-MM) بالتوقيت المحلي. */
export const ordersInMonth = (orders: Order[], month: string) =>
  orders.filter((o) => !o.is_deleted && o.type === 'sale' && localMonthKey(o.date) === month);
