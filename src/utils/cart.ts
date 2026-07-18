// ============================================================================
// مساعدات السلة — دوال خالصة (بلا supabase) عشان تتختبر لوحدها
// ============================================================================
import type { OrderItem } from '../store/useStore';

// سطر السلة = منتج + موظف. لازم مفتاح مركّب وإلا لو نفس الخدمة اتعملت من
// كابتنين مختلفين هيتدمجوا في سطر واحد وتضيع نسبة واحد منهم.
export const cartLineId = (productId: string, salespersonId?: string | null) =>
  `${productId}::${salespersonId || 'none'}`;

// إجمالي كمية منتج في السلة عبر كل أسطره (مع إمكانية استثناء سطر).
// المخزون لازم يتقاس على المجموع ده مش على سطر لوحده، وإلا كل سطر بياخد
// المخزون كامل وينفع نبيع ضعف الموجود.
export const cartQtyOfProduct = (cart: OrderItem[], productId: string, exceptLineId?: string) =>
  cart.reduce((sum, i) => (i.id === productId && i.line_id !== exceptLineId ? sum + (Number(i.quantity) || 0) : sum), 0);

// مجموع الكميات المطلوبة لكل منتج في السلة (product_id → إجمالي الكمية).
// لازم نجمّع الأول: لو المنتج في سطرين (موظفين مختلفين) وخصمنا سطر سطر،
// التحديث التاني بيقرا نفس المخزون القديم ويكتب فوق الأول.
export const cartQtyByProduct = (cart: OrderItem[]): Map<string, number> => {
  const map = new Map<string, number>();
  for (const item of cart) map.set(item.id, (map.get(item.id) || 0) + (Number(item.quantity) || 0));
  return map;
};
