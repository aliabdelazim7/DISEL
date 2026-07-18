import { calculateOrderReturnValue } from './returns';

export function calculateInvoiceProfit(order: any): number {
  if (!order || order.type === 'payment' || order.is_deleted) return 0;

  const items = order.items || [];
  const returnedValue = calculateOrderReturnValue(order);
  const effectiveTotal = Math.max(0, (Number(order.total) || 0) - returnedValue);
  const netCost = items.reduce((sum: number, item: any) => {
    const netQty = (Number(item.quantity) || 0) - (Number(item.returned_quantity) || 0);
    const unitCost = Number(item.average_purchase_price ?? item.purchase_price ?? 0) || 0;
    return sum + (netQty * unitCost);
  }, 0);

  return effectiveTotal - netCost;
}
