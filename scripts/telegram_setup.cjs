/**
 * مساعد تفعيل بوت تليجرام
 * ============================================================================
 * بيجيب الـ Chat ID (أصعب خطوة) وبيبعت رسالة تجربة عشان تتأكد إن كل حاجة تمام.
 *
 * الاستخدام:
 *   1) اعمل بوت من @BotFather في تليجرام → /newbot → هياخد منك اسم ويديك TOKEN
 *   2) ابعت أي رسالة للبوت من حسابك (أو ضيفه لجروب وابعت رسالة فيه)
 *   3) شغّل:
 *        node scripts/telegram_setup.cjs <TOKEN>
 *
 *   وللتجربة على شات معيّن:
 *        node scripts/telegram_setup.cjs <TOKEN> <CHAT_ID>
 * ============================================================================
 */

const token = process.argv[2];
const testChatId = process.argv[3];

if (!token) {
  console.error(`
❌ ناقص التوكن.

   الاستخدام:  node scripts/telegram_setup.cjs <TOKEN> [CHAT_ID]

   تجيب التوكن منين؟
     افتح تليجرام → دوّر على @BotFather → /newbot
     هيسألك على اسم البوت ويوزرنيم، وبعدها هيديك توكن شكله كده:
       8123456789:AAH_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
`);
  process.exit(1);
}

const api = (method, body) =>
  fetch(`https://api.telegram.org/bot${token}/${method}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body || {}),
  }).then((r) => r.json());

(async () => {
  // ── 1) التأكد إن التوكن شغال ──────────────────────────────────────────────
  const me = await api('getMe');
  if (!me.ok) {
    console.error(`\n❌ التوكن مش مظبوط: ${me.description || 'خطأ غير معروف'}`);
    console.error('   اتأكد إنك نسخته كامل من BotFather من غير مسافات.\n');
    process.exit(1);
  }
  console.log(`\n✅ البوت شغال: ${me.result.first_name}  (@${me.result.username})`);

  // ── 2) رسالة تجربة لو الشات محدد ─────────────────────────────────────────
  if (testChatId) {
    const sent = await api('sendMessage', {
      chat_id: testChatId,
      text: '✅ تجربة من نظام الكاشير — البوت شغال تمام.',
    });
    if (sent.ok) {
      console.log(`\n✅ الرسالة وصلت للشات ${testChatId} — شوف تليجرام.\n`);
    } else {
      console.error(`\n❌ الرسالة ما وصلتش: ${sent.description}`);
      console.error('   غالباً لازم تبعت للبوت رسالة الأول من الحساب ده.\n');
      process.exit(1);
    }
    return;
  }

  // ── 3) استخراج الـ Chat IDs من الرسائل الواصلة ────────────────────────────
  const updates = await api('getUpdates');
  const chats = new Map();
  for (const u of updates.result || []) {
    const msg = u.message || u.channel_post || u.edited_message;
    if (!msg?.chat) continue;
    const c = msg.chat;
    const label = c.title || [c.first_name, c.last_name].filter(Boolean).join(' ') || c.username || '—';
    chats.set(c.id, `${label}  (${c.type})`);
  }

  if (chats.size === 0) {
    console.log(`
⚠️  مفيش رسائل واصلة للبوت لحد دلوقتي، فمش قادر أجيب الـ Chat ID.

   اعمل كده:
     • للحساب الشخصي: افتح البوت في تليجرام (@${me.result.username}) واضغط Start
       أو ابعتله أي رسالة.
     • للجروب: ضيف البوت للجروب وابعت أي رسالة فيه.

   وبعدين شغّل السكربت تاني.
`);
    process.exit(1);
  }

  console.log('\n📋 الشاتات اللي البوت شايفها:\n');
  for (const [id, label] of chats) console.log(`   ${id}   ←  ${label}`);

  const ids = [...chats.keys()].join(',');
  console.log(`
────────────────────────────────────────────────────────────────
حط دول في Vercel → Settings → Environment Variables:

   TELEGRAM_BOT_TOKEN = ${token}
   TELEGRAM_CHAT_ID   = ${ids}

(لو عايز أكتر من حد يستقبل التنبيهات، سيب الـ IDs بفاصلة زي ما هي فوق.)

⚠️  التوكن ده سر — متحطهوش في الكود ولا ترفعه على GitHub.

بعد ما تحطهم: Vercel → Deployments → آخر واحد → Redeploy
────────────────────────────────────────────────────────────────
`);
})().catch((e) => {
  console.error('\n❌ خطأ في الاتصال بتليجرام:', e.message, '\n');
  process.exit(1);
});
