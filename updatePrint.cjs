const fs = require('fs');
let code = fs.readFileSync('src/pages/admin/Invoices.tsx', 'utf-8');
const handlePrintStart = code.indexOf('  const handlePrint = (order: any) => {');
const handlePrintEnd = code.indexOf('  // Extract unique years from orders');

const newHandlePrint = `  const handlePrint = (order: any) => {
    const printDate = new Date(order.created_at || Date.now()).toLocaleString('ar-EG', { calendar: 'gregory', day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
    const isPayment = order.type === 'payment';
    const subtotal = isPayment ? order.total : order.items.reduce((sum: number, item: any) => sum + (item.sale_price * item.quantity), 0);
    const taxValue = isPayment ? 0 : Math.max(0, order.total - (subtotal - (order.discount || 0)));
    
    let debtAfter = 0;
    if (order.customer && !order.is_deleted) {
      const customerOrders = activeOrders.filter(o => o.customer?.id === order.customer.id);
      const sortedOrders = [...customerOrders].sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
      const currentIndex = sortedOrders.findIndex(o => o.id === order.id);
      
      const calcDebt = (upToIndex: number) => sortedOrders.slice(0, upToIndex).reduce((sum, o) => {
        const returnedValue = calculateOrderReturnValue(o);
        const effectiveTotal = o.type === 'payment' ? 0 : (o.total - returnedValue);
        const debt = effectiveTotal - (o.paid_amount || 0);

        if (debt > 0.009 && o.type !== 'payment') {
          return sum + debt;
        } else if (o.type === 'payment' && !(o.notes && o.notes.includes('سداد أجل للفاتورة رقم'))) {
          return sum + debt;
        }
        return sum;
      }, 0);

      debtAfter = calcDebt(currentIndex + 1);
    }

    const cart = isPayment 
      ? [{name: order.notes || 'سداد مديونية سابقة', quantity: 1, sale_price: order.paid_amount}] 
      : order.items;

    const itemsHtml = cart.map((item: any, index: number) =>
      \`<tr>
        <td style="padding:10px 4px;border-bottom:1px solid #eee;text-align:center;font-weight:bold;color:#666;">\${index + 1}</td>
        <td style="padding:10px 4px;border-bottom:1px solid #eee;font-weight:900;font-size:14px;">\${item.name}\${item.returned_quantity > 0 ? \` <span style="color:red;font-size:10px;">(مرتجع: \${item.returned_quantity})</span>\` : ''}</td>
        <td style="padding:10px 4px;border-bottom:1px solid #eee;text-align:center;font-weight:bold;">\${item.quantity}</td>
        <td style="padding:10px 4px;border-bottom:1px solid #eee;text-align:center;font-weight:bold;">\${item.sale_price.toFixed(2)}</td>
        <td style="padding:10px 4px;border-bottom:1px solid #eee;text-align:left;font-weight:black;font-size:15px;">\${(item.sale_price * item.quantity).toFixed(2)}</td>
      </tr>\`
    ).join('');

    const invoiceUrl = \`\${window.location.origin}/view-invoice/\${order.id}\`;
    const qrCodeUrl = \`https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=\${encodeURIComponent(invoiceUrl)}\`;

    const customerBlock = order.customer
      ? \`<div class="customer-info-grid">
            <div class="info-item"><strong>اسم العميل:</strong> <span>\${order.customer.name || '—'}</span></div>
            <div class="info-item"><strong>رقم الهاتف:</strong> <span dir="ltr">\${order.customer.phone || '—'}</span></div>
            <div class="info-item"><strong>رقم الكارت (ID):</strong> <span dir="ltr">\${order.customer.custom_id || order.customer.id.substring(0, 8) || '—'}</span></div>
            <div class="info-item"><strong>رقم الفاتورة:</strong> <span>#\${order.id}</span></div>
            <div class="info-item"><strong>المسؤول:</strong> <span>\${order.cashier_name || '—'}</span></div>
            <div class="info-item"><strong>التاريخ:</strong> <span>\${printDate}</span></div>
            <div class="info-item" style="grid-column: span 2; border-top: 1px dashed #e2e8f0; padding-top: 4px; margin-top: 2px;">
              <strong>إجمالي المديونية الحالية:</strong> 
              <span style="color: #dc2626; font-size: 14px;">\${(debtAfter || 0).toFixed(2)} \${storeSettings.currency}</span>
            </div>
         </div>\`
      : \`<div class="customer-info-grid">
            <div class="info-item"><strong>اسم العميل:</strong> <span>عميل نقدي</span></div>
            <div class="info-item"><strong>رقم الفاتورة:</strong> <span>#\${order.id}</span></div>
            <div class="info-item"><strong>المسؤول:</strong> <span>\${order.cashier_name || '—'}</span></div>
            <div class="info-item"><strong>التاريخ:</strong> <span>\${printDate}</span></div>
         </div>\`;

    const html = \`<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="UTF-8"/>
<title>فاتورة بيع #\${order.id}</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Cairo:wght@400;700;900&display=swap');
  *{margin:0;padding:0;box-sizing:border-box;font-family:'Cairo', sans-serif;}
  body{background:#fff;color:#1e293b;padding:0;margin:0;}
  .invoice-container{width:148mm;min-height:100mm;margin:0 auto;padding:5mm;position:relative;display:flex;flex-direction:column;gap:5px;}
  
  .header-main{display:flex;justify-content:space-between;align-items:center;border-bottom:3px solid #1e293b;padding-bottom:5px;margin-bottom:5px;}
  .logo{width:80px;height:80px;object-fit:contain;border-radius:12px;border:1px solid #e2e8f0;padding:2px;background:#fff;}
  .store-name{font-size:24px;font-weight:900;color:#1e293b;line-height:1.2;}
  .store-details{font-size:10px;color:#64748b;margin-top:3px;line-height:1.3;font-weight:bold;}
  .store-info-center{flex:1;display:flex;flex-direction:column;align-items:center;text-align:center;padding:0 10px;}
  
  .customer-info-grid{display:grid;grid-template-columns:1fr 1fr;gap:4px;margin-bottom:5px;background:#f8fafc;padding:8px;border-radius:10px;border:1px solid #e2e8f0;}
  .info-item{font-size:12px;display:flex;gap:6px;}
  .info-item strong{color:#64748b;white-space:nowrap;}
  .info-item span{color:#1e293b;font-weight:700;}
  
  .qr-code-container{display:flex;flex-direction:column;align-items:center;gap:3px;}
  .qr-code-img{width:80px;height:80px;padding:3px;background:#fff;border-radius:10px;border:1px solid #e2e8f0;box-shadow: 0 1px 3px rgba(0,0,0,0.1);}
  .qr-label{font-size:10px;font-weight:900;color:#1e293b;text-align:center;margin-top:2px;background:#f1f5f9;padding:2px 8px;border-radius:4px;}

  table{width:100%;border-collapse:collapse;margin-bottom:5px;}
  thead th{background:#f1f5f9;color:#475569;font-size:12px;padding:8px 6px;text-align:center;border-bottom:2px solid #cbd5e1;}
  thead th:nth-child(2){text-align:right;}
  thead th:last-child{text-align:left;}
  
  .summary-section{margin-right:auto;width:60%;margin-top:5px;}
  .summary-row{display:flex;justify-content:space-between;padding:5px 0;font-size:13px;border-bottom:1px solid #f1f5f9;}
  .summary-row.total{border-top:2px solid #1e293b;border-bottom:none;margin-top:3px;font-size:18px;font-weight:900;color:#1e293b;}
  
  .payment-status{margin-top:8px;padding:6px;border-radius:6px;text-align:center;font-weight:bold;font-size:13px;}
  .status-paid{background:#ecfdf5;color:#059669;border:1px solid #a7f3d0;}
  .status-debt{background:#fef2f2;color:#dc2626;border:1px solid #fecaca;}
  
  .footer{text-align:center;margin-top:15px;padding-top:10px;border-top:1px dashed #cbd5e1;font-size:11px;color:#94a3b8;font-weight:bold;}
  
  @media print{
    @page{size:A5;margin:0;}
    body{-webkit-print-color-adjust:exact;}
    .invoice-container{width:148mm;height:auto;padding:5mm;}
  }
</style>
</head>
<body>
<div class="invoice-container">
  <div class="header-main">
    <img class="logo" src="\${storeSettings.logo}" onerror="this.style.display='none'" />
    
    <div class="store-info-center">
      <div class="store-name">\${storeSettings.name}</div>
      <div class="store-details">
        \${storeSettings.address ? \`📍 \${storeSettings.address}<br/>\` : ''}
        \${storeSettings.phone ? \`📞 \${storeSettings.phone}\` : ''}
        \${storeSettings.phone2 ? \` | \${storeSettings.phone2}\` : ''}
      </div>
    </div>

    <div class="qr-code-container">
      <img class="qr-code-img" src="\${qrCodeUrl}" alt="QR Code" />
      <div class="qr-label">تفاصيل الفاتورة</div>
    </div>
  </div>

  \${customerBlock}

  <table>
    <thead><tr>
      <th style="width:40px">#</th>
      <th style="text-align:right">\${isPayment ? 'البيان' : 'المنتج'}</th>
      <th style="width:60px">\${isPayment ? '' : 'الكمية'}</th>
      <th style="width:80px">\${isPayment ? '' : 'السعر'}</th>
      <th style="width:100px;text-align:left">الإجمالي</th>
    </tr></thead>
    <tbody>\${itemsHtml}</tbody>
  </table>

  <div class="summary-section">
    \${!isPayment ? \`
    <div class="summary-row"><span>المجموع الفرعي:</span><span>\${subtotal.toFixed(2)} \${storeSettings.currency}</span></div>
    \${order.coupon_code ? \`<div class="summary-row" style="color:#e53e3e;font-weight:700;"><span>كوبون (\${order.coupon_code}):</span><span>- \${(order.discount_amount || 0).toFixed(2)} \${storeSettings.currency}</span></div>\` : ''}
    \${(order.discount && !order.coupon_code) ? \`<div class="summary-row" style="color:#e53e3e;font-weight:700;"><span>خصم الفاتورة:</span><span>- \${order.discount.toFixed(2)} \${storeSettings.currency}</span></div>\` : ''}
    <div class="summary-row"><span>الضريبة (\${storeSettings.taxRate}%):</span><span>\${taxValue.toFixed(2)} \${storeSettings.currency}</span></div>
    <div class="summary-row total"><span>الإجمالي النهائي:</span><span>\${order.total.toFixed(2)} \${storeSettings.currency}</span></div>
    \` : ''}
  
    \${(order.paid_amount !== undefined && order.paid_amount < order.total) ? \`
      <div class="payment-status status-debt">
        <div>متبقي للتحصيل (آجل): \${(order.total - (order.paid_amount || 0)).toFixed(2)} \${storeSettings.currency}</div>
        <div style="font-size:11px;opacity:0.8;margin-top:2px;">تم سداد: \${(order.paid_amount || 0).toFixed(2)} \${storeSettings.currency}</div>
      </div>
    \` : \`
      <div class="payment-status status-paid">✓ تم سداد الفاتورة بالكامل</div>
    \`}
    
    <div style="margin-top:10px; padding:8px; background:#f9fafb; border-radius:8px; border:1px solid #eee;">
      <div style="font-size:11px; color:#64748b; margin-bottom:4px; border-bottom:1px solid #eee; padding-bottom:2px; text-align:right;">تفاصيل الدفع:</div>
      \${order.paid_cash > 0 ? \`<div class="summary-row" style="font-size:12px;"><span>💵 كاش:</span><span>\${order.paid_cash.toFixed(2)}</span></div>\` : ''}
      \${order.paid_visa > 0 ? \`<div class="summary-row" style="font-size:12px;"><span>💳 فيزا:</span><span>\${order.paid_visa.toFixed(2)}</span></div>\` : ''}
      \${order.paid_wallet > 0 ? \`<div class="summary-row" style="font-size:12px;"><span>📱 محفظة:</span><span>\${order.paid_wallet.toFixed(2)}</span></div>\` : ''}
      \${order.paid_instapay > 0 ? \`<div class="summary-row" style="font-size:12px;"><span>⚡ انستا باي:</span><span>\${order.paid_instapay.toFixed(2)}</span></div>\` : ''}
    </div>
  </div>

  <div class="footer">شكراً لثقتكم بنا - \${storeSettings.name} ترحب بكم دائماً</div>
</div>
<script>window.onload=()=>{setTimeout(()=>{window.print();window.onafterprint=()=>window.close();},500);}</script>
</body></html>\`;

    const pw = window.open('', '_blank', 'width=800,height=1000');
    if (pw) { pw.document.write(html); pw.document.close(); }
  };
`;

code = code.substring(0, handlePrintStart) + newHandlePrint + '\n' + code.substring(handlePrintEnd);
fs.writeFileSync('src/pages/admin/Invoices.tsx', code);
