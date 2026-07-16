import { useStore } from '../../store/useStore';
import { WifiOff, RefreshCw, AlertCircle, ShoppingCart, RotateCcw, Calendar, User, Package, CheckCircle2, CloudOff } from 'lucide-react';

export default function OfflineInvoices() {
  const { offlineQueue, offlineReturnsQueue, isSyncing, isOnline, syncOfflineQueue, syncOfflineReturnsQueue } = useStore();
  
  const handleSync = async () => {
    if (!isOnline) {
      alert('أنت غير متصل بالإنترنت حالياً. لا يمكن المزامنة.');
      return;
    }
    
    try {
      await syncOfflineQueue();
      await syncOfflineReturnsQueue();
      alert('تمت المزامنة بنجاح!');
    } catch (error) {
      alert('حدث خطأ أثناء المزامنة، حاول مرة أخرى');
    }
  };

  const pendingCount = offlineQueue.length + offlineReturnsQueue.length;

  return (
    <div className="space-y-8 pb-12 animate-in fade-in slide-in-from-bottom-4 duration-500">
      {/* Header */}
      <div className="bg-gradient-to-r from-indigo-900 via-indigo-800 to-violet-900 rounded-[32px] p-8 md:p-10 text-white shadow-xl shadow-indigo-900/20 relative overflow-hidden group">
        <div className="absolute top-0 right-0 w-96 h-96 bg-white/10 rounded-full blur-3xl -translate-y-1/2 translate-x-1/3 group-hover:bg-white/20 transition-all duration-700"></div>
        <div className="absolute bottom-0 left-0 w-96 h-96 bg-fuchsia-500/20 rounded-full blur-3xl translate-y-1/3 -translate-x-1/4 group-hover:bg-fuchsia-500/30 transition-all duration-700"></div>
        
        <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-8">
          <div>
            <div className="inline-flex items-center gap-2 bg-white/10 backdrop-blur-md px-3 py-1.5 rounded-full text-indigo-100 text-sm font-medium mb-4">
              <CloudOff size={16} />
              <span>إدارة حالة الاتصال</span>
            </div>
            <h1 className="text-4xl font-black mb-3 tracking-tight">
              الفواتير الأوفلاين
            </h1>
            <p className="text-indigo-200/90 font-medium max-w-xl text-lg">
              متابعة ومزامنة الفواتير والمرتجعات التي تمت أثناء انقطاع الإنترنت، لضمان عدم ضياع أي بيانات.
            </p>
          </div>
          
          <div className="flex flex-col items-center gap-3">
            <button 
              onClick={handleSync}
              disabled={isSyncing || pendingCount === 0 || !isOnline}
              className="group/btn relative overflow-hidden bg-white text-indigo-900 px-8 py-4 rounded-2xl font-black flex items-center justify-center gap-3 hover:bg-indigo-50 transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-xl hover:shadow-2xl hover:-translate-y-1 w-full md:w-auto"
            >
              <div className="absolute inset-0 bg-gradient-to-r from-indigo-100 to-white opacity-0 group-hover/btn:opacity-100 transition-opacity"></div>
              <RefreshCw size={22} className={`relative z-10 ${isSyncing ? 'animate-spin text-indigo-600' : 'text-indigo-500 group-hover/btn:rotate-180 transition-transform duration-500'}`} />
              <span className="relative z-10">{isSyncing ? 'جاري المزامنة...' : `مزامنة الآن (${pendingCount})`}</span>
            </button>
            {!isOnline && (
               <div className="text-red-200 text-xs font-bold bg-red-500/20 px-3 py-1 rounded-full flex items-center gap-1 animate-pulse">
                 <AlertCircle size={12} /> بانتظار عودة الإنترنت
               </div>
            )}
          </div>
        </div>
      </div>

      {!isOnline && (
        <div className="bg-gradient-to-r from-red-50 to-orange-50 border border-red-100 rounded-3xl p-5 flex items-start sm:items-center gap-4 text-red-800 shadow-sm">
          <div className="bg-red-100 p-3 rounded-full shrink-0">
            <WifiOff className="text-red-600" size={24} />
          </div>
          <div>
            <p className="font-bold text-lg mb-1">أنت حالياً في وضع الأوفلاين</p>
            <p className="font-medium text-red-600/80 text-sm">لا تقلق، النظام يعمل بشكل طبيعي! سيتم حفظ أي فواتير جديدة أو مرتجعات هنا حتى يعود الاتصال بالإنترنت.</p>
          </div>
        </div>
      )}

      {pendingCount === 0 ? (
        <div className="bg-gradient-to-b from-white to-slate-50 rounded-[40px] p-16 text-center shadow-lg shadow-slate-200/40 border border-slate-100/60 flex flex-col items-center justify-center relative overflow-hidden">
          <div className="absolute inset-0 bg-[url('https://www.transparenttextures.com/patterns/cubes.png')] opacity-[0.03]"></div>
          
          <div className="relative">
            <div className="absolute -inset-4 bg-emerald-100 rounded-full animate-ping opacity-20"></div>
            <div className="w-32 h-32 bg-gradient-to-br from-emerald-100 to-teal-50 rounded-full flex items-center justify-center mb-8 relative shadow-inner">
              <CheckCircle2 className="text-emerald-500 drop-shadow-md" size={64} />
            </div>
          </div>
          
          <h2 className="text-3xl font-black text-slate-800 mb-3 tracking-tight">كل شيء متزامن!</h2>
          <p className="text-slate-500 font-medium text-lg max-w-lg mx-auto leading-relaxed">
            جميع الفواتير والمرتجعات متزامنة مع السيرفر السحابي بشكل كامل. لا توجد أي عمليات تمت في وضع الأوفلاين تنتظر الرفع.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Offline Orders Queue */}
          <div className="bg-white rounded-[32px] shadow-sm border border-slate-100 overflow-hidden flex flex-col">
            <div className="bg-slate-50/50 p-6 border-b border-slate-100 flex items-center justify-between">
              <h2 className="text-xl font-black text-slate-800 flex items-center gap-3">
                <div className="bg-indigo-100 p-2 rounded-xl text-indigo-600">
                  <ShoppingCart size={20} />
                </div>
                فواتير معلقة
              </h2>
              <span className="bg-indigo-600 text-white px-3 py-1 rounded-full text-sm font-bold shadow-sm">
                {offlineQueue.length}
              </span>
            </div>
            
            <div className="p-6 bg-slate-50/30 flex-1">
              {offlineQueue.length === 0 ? (
                <div className="h-full flex flex-col items-center justify-center text-slate-400 py-12">
                  <ShoppingCart size={48} className="mb-4 opacity-20" />
                  <p className="font-medium">لا توجد فواتير بيع معلقة</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {offlineQueue.map((order) => (
                    <div key={order.id} className="bg-white border border-slate-100 shadow-sm rounded-2xl p-5 hover:shadow-md hover:border-indigo-100 transition-all group">
                      <div className="flex justify-between items-start mb-4">
                        <div>
                          <div className="font-black text-slate-800 text-lg mb-1 flex items-center gap-2">
                            {order.id}
                            <span className="bg-amber-100 text-amber-700 text-[10px] px-2 py-0.5 rounded-full font-bold">بانتظار الرفع</span>
                          </div>
                          <div className="flex items-center gap-2 text-xs text-slate-500 font-medium">
                            <Calendar size={14} className="text-indigo-400" />
                            {new Date(order.date).toLocaleString('ar-EG')}
                          </div>
                        </div>
                        <div className="bg-gradient-to-r from-indigo-50 to-blue-50 text-indigo-700 px-4 py-2 rounded-xl text-sm font-black shadow-sm border border-indigo-100/50">
                          {order.total.toLocaleString()} ج.م
                        </div>
                      </div>
                      
                      <div className="grid grid-cols-2 gap-3 text-sm text-slate-600 mb-4 bg-slate-50/50 p-3 rounded-xl border border-slate-100/50">
                        <div className="flex items-center gap-2 font-medium truncate">
                          <User size={14} className="text-slate-400 shrink-0" />
                          <span className="truncate">{order.customer?.name || 'عميل نقدي'}</span>
                        </div>
                        <div className="flex items-center gap-2 font-medium truncate">
                          <User size={14} className="text-slate-400 shrink-0" />
                          <span className="truncate">كاشير: {order.cashier_name || 'غير محدد'}</span>
                        </div>
                      </div>

                      <div className="border-t border-slate-100 pt-3">
                        <p className="text-xs font-bold text-slate-500 mb-3 flex items-center gap-1.5">
                          <Package size={14} className="text-slate-400" />
                          المنتجات المشتراة ({order.items.length})
                        </p>
                        <div className="flex flex-wrap gap-2">
                          {order.items.map((item: any, idx: number) => (
                            <span key={idx} className="bg-white border border-slate-200 text-slate-700 text-xs font-bold px-2.5 py-1 rounded-lg shadow-sm flex items-center gap-1">
                              <span className="text-indigo-500">{item.quantity}x</span> {item.name}
                            </span>
                          ))}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* Offline Returns Queue */}
          <div className="bg-white rounded-[32px] shadow-sm border border-slate-100 overflow-hidden flex flex-col">
            <div className="bg-slate-50/50 p-6 border-b border-slate-100 flex items-center justify-between">
              <h2 className="text-xl font-black text-slate-800 flex items-center gap-3">
                <div className="bg-rose-100 p-2 rounded-xl text-rose-600">
                  <RotateCcw size={20} />
                </div>
                مرتجعات معلقة
              </h2>
              <span className="bg-rose-600 text-white px-3 py-1 rounded-full text-sm font-bold shadow-sm">
                {offlineReturnsQueue.length}
              </span>
            </div>
            
            <div className="p-6 bg-slate-50/30 flex-1">
              {offlineReturnsQueue.length === 0 ? (
                <div className="h-full flex flex-col items-center justify-center text-slate-400 py-12">
                  <RotateCcw size={48} className="mb-4 opacity-20" />
                  <p className="font-medium">لا توجد عمليات إرجاع معلقة</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {offlineReturnsQueue.map((ret, idx) => (
                    <div key={idx} className="bg-white border border-slate-100 shadow-sm rounded-2xl p-5 hover:shadow-md hover:border-rose-100 transition-all group">
                      <div className="flex justify-between items-start mb-4">
                        <div>
                          <div className="font-black text-slate-800 text-lg mb-1 flex items-center gap-2">
                            عملية إرجاع
                            <span className="bg-amber-100 text-amber-700 text-[10px] px-2 py-0.5 rounded-full font-bold">بانتظار الرفع</span>
                          </div>
                          <div className="flex items-center gap-2 text-xs text-slate-500 font-medium">
                            <span className="text-rose-400">#</span>
                            رقم الفاتورة الأصلية: <span className="font-bold text-slate-700">{ret.orderId}</span>
                          </div>
                        </div>
                        <div className="bg-rose-50 text-rose-700 px-4 py-2 rounded-xl text-sm font-black shadow-sm border border-rose-100/50 flex items-center gap-1.5">
                          {ret.returns.length} منتجات
                        </div>
                      </div>
                      
                      <div className="border-t border-slate-100 pt-3">
                        <div className="flex flex-col gap-2">
                          {ret.returns.map((item: any, i: number) => (
                            <div key={i} className="flex items-center justify-between text-sm bg-slate-50 p-3 rounded-xl border border-slate-100/50 font-medium text-slate-700">
                              <span className="flex items-center gap-2">
                                <Package size={14} className="text-slate-400" />
                                كود: {item.productId.substring(0,8)}...
                              </span>
                              <span className="bg-white text-rose-600 font-black px-2 py-1 rounded-md shadow-sm border border-slate-100 flex items-center gap-1">
                                <RotateCcw size={12} />
                                {item.returnQty} قطعة
                              </span>
                            </div>
                          ))}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
