// تحويل ملف صورة إلى Data URL مضغوط (ثمبنيل) لتخزينه في عمود products.image_url (نص).
// نصغّر الصورة ونضغطها JPEG أولاً عشان ما تتقّلش تحميل المنتجات ولا حجم قاعدة البيانات
// (صورة الموبايل ممكن تكون 3–5 ميجا؛ الثمبنيل بيطلع ~20–50 كيلو).
export async function fileToThumbnailDataUrl(
  file: File,
  maxSize = 400,
  quality = 0.72,
): Promise<string> {
  const dataUrl = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result as string);
    reader.onerror = () => reject(new Error('تعذّر قراءة الصورة'));
    reader.readAsDataURL(file);
  });

  const img = await new Promise<HTMLImageElement>((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error('ملف الصورة غير صالح'));
    image.src = dataUrl;
  });

  let { width, height } = img;
  if (width > height && width > maxSize) {
    height = Math.round((height * maxSize) / width);
    width = maxSize;
  } else if (height >= width && height > maxSize) {
    width = Math.round((width * maxSize) / height);
    height = maxSize;
  }

  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');
  if (!ctx) return dataUrl; // fallback: الأصلية لو الكانفاس مش متاح
  ctx.drawImage(img, 0, 0, width, height);
  return canvas.toDataURL('image/jpeg', quality);
}
