// Value of the GOODS returned on an order — used to reduce an invoice's
// effective total (i.e. for debt and profit calculations). Independent of how
// (or whether) the customer was refunded in cash.
export function calculateOrderReturnValue(order: any): number {
  const items = order?.items || [];

  const itemsSum = items.reduce((sum: number, item: any) => {
    return sum + ((Number(item.quantity) || 0) * (Number(item.sale_price) || 0));
  }, 0);
  const discountRatio = itemsSum > 0 ? (Number(order?.total) || 0) / itemsSum : 1;

  return items.reduce((sum: number, item: any) => {
    return sum + ((Number(item.returned_quantity) || 0) * (Number(item.sale_price) || 0));
  }, 0) * discountRatio;
}

// Cash actually refunded to the customer — used for treasury / cash-flow.
// A return settled against the customer's debt refunds no cash, so it counts
// as 0 here (it only reduces the customer's deferred balance, see
// calculateOrderReturnValue for that side).
export function calculateCashRefunded(order: any): number {
  const items = order?.items || [];
  return items.reduce((sum: number, item: any) => sum + (Number(item.refunded_amount) || 0), 0);
}
