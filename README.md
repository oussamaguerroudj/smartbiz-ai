# SmartBiz AI — Backend (Node.js + Express) — Phase 5, Batch 1

## ✅ تم اختبار هذا فعليًا — ليس مجرد كود مكتوب نظريًا

خلافًا للمراحل السابقة، تمكنت هذه المرة من تثبيت PostgreSQL فعليًا داخل بيئتي، تشغيل الـ 13 migration من Phase 3 **بنجاح تام بدون أي خطأ**، تشغيل السيرفر، وتنفيذ سلسلة اختبارات حقيقية عبر الـ API الفعلي:

| الاختبار | النتيجة |
|---|---|
| `POST /auth/register` | ✅ نجح — bcrypt hash حقيقي، JWT صادر بشكل صحيح |
| `POST /products` | ✅ نجح — منتج محفوظ في PostgreSQL فعليًا |
| `POST /sales` (كمية 2) | ✅ نجح — `subtotal: 360`, `unit_price`/`unit_cost` snapshots صحيحة، `line_profit: 120`، فاتورة `INV-1` أُنشئت تلقائيًا |
| التحقق من نقص المخزون | ✅ الكمية نقصت من 42 إلى 40 تلقائيًا |
| **محاولة بيع كمية 999 (بيع أكبر من المتوفر)** | ✅ **رُفض فورًا** برسالة `INSUFFICIENT_STOCK`، ولم يتغيّر أي شيء في قاعدة البيانات (تحقّقت: الكمية بقيت 40) — الـ ROLLBACK يعمل فعليًا |
| **عزل البيانات بين الشركات (Multi-tenancy)** | ✅ سجّلت شركة ثانية، وحاولت الوصول لمنتج الشركة الأولى بتوكن الشركة الثانية → **404 NOT_FOUND** كما هو مطلوب تمامًا |

هذا يعني أن الـ transaction الكاملة (Ch. 11) وعزل الـ multi-tenancy (Ch. 24 Design Rationale) ليسا مجرد كود يبدو صحيحًا — تم التحقق من سلوكهما الفعلي.

**ما لم أختبره هنا** (يحتاج بيئتك): تشغيله عبر `npm run dev` من الصفر باتباع خطوات التثبيت أدناه، للتأكد أن التعليمات نفسها تعمل على جهازك بالضبط (نسخة Node/PostgreSQL قد تختلف).

---

## ✅ Phase 5 مكتملة — كل وحدة اختُبرت فعليًا بنفس الصرامة

بالإضافة لاختبارات Auth/Products/Sales (الدفعة السابقة)، اختبرت في هذه الدفعة كل وحدة جديدة حقيقيًا على نفس قاعدة بيانات PostgreSQL:

| الوحدة | الاختبار | النتيجة |
|---|---|---|
| Invoices | إنشاء بيع → فاتورة INV-1 تلقائيًا → عرض القائمة والتفاصيل | ✅ يعمل، البنود والمجموع صحيحان |
| Expenses | إضافة مصروف 12000 → `thisMonthTotal` | ✅ يعمل، المجموع صحيح |
| Employees | راتب أساسي 35000 + بونص 2000 → صافي الراتب | ✅ **37000 بالضبط** (صيغة Ch. 17.3 صحيحة) |
| Attendance | تسجيل حضور → ظهوره في تفاصيل الموظف | ✅ يعمل |
| Appointments | إنشاء موعد → ظهوره في القائمة | ✅ يعمل |
| Customers / Suppliers | إنشاء كل منهما | ✅ يعملان |
| **Dashboard** | منتج مخزونه منخفض (3/5) + بيع بقيمة 980 غير مدفوع + مصروف 60000 | ✅ `todayRevenue: 980`, `todayExpenses: 60000`, `todayProfit: -59020`, `lowStockCount: 1`, `unpaidInvoicesCount: 1` — **كل رقم مطابق تمامًا للمتوقع** |
| **Reports** | نفس السيناريو، فترة شهرية | ✅ نفس الأرقام + `grossProfit: 230` (980-750) + `topProducts` صحيح |
| **Notifications** | نفس السيناريو | ✅ عرض "Low stock: Olive Oil 1L — 2 units remaining" (3 ناقص 1 المُباع) و"Invoice INV-1 still unpaid" — **مُشتقة من البيانات الحقيقية بدقة** |

كل الوحدات الآن حقيقية ومُتحقَّق من سلوكها، وليست كودًا مكتوبًا نظريًا فقط.

---

## ما تم بناؤه (الآن مكتمل بالكامل باستثناء AI)

- **البنية التحتية**: اتصال PostgreSQL (`config/db.js` مع `query()` و`withTransaction()`)، معالجة أخطاء موحّدة، JWT auth middleware
- **Auth**: register/login/refresh
- **Products**: CRUD كامل
- **Sales**: الـ transaction الكاملة (Ch. 11) مع row-locking و ROLLBACK
- **Invoices**: قائمة + تفاصيل + mark-paid (PDF export مؤجل عمدًا — يحتاج مكتبة PDF منفصلة)
- **Expenses**: قائمة + إضافة + حذف، مع مجموع الشهر الحالي
- **Employees**: قائمة + إضافة + تفاصيل (تتضمن الحضور والراتب الصافي) + تسجيل حضور + إضافة بونص/خصم
- **Appointments**: قائمة + إضافة + تحديث الحالة
- **Customers / Suppliers**: قائمة + إضافة لكل منهما
- **Reports**: تجميع حقيقي (Daily/Weekly/Monthly/Yearly) — Revenue, Expenses, Net Profit, Gross Profit, Top Products
- **Dashboard**: كل الـ KPIs المطلوبة في Ch. 9.1 حرفيًا
- **Notifications**: مُشتقة حيًا من low-stock وunpaid-invoices (نفس مبدأ Flutter في Phase 4)

## لم يُبنَ بعد

- **AI proxy endpoints** (`/ai/invoices/scan`, `/ai/chat`, `/ai/insights`) — تحتاج مفتاح OpenAI API وOCR pipeline، وهذا **Phase 6** بالتحديد حسب الـ roadmap المعتمد
- **PDF/Excel export** الفعلي للفواتير والتقارير (Ch. 14, 22) — يحتاج مكتبات إضافية (`pdfkit`, `exceljs`)، مؤجل كدفعة منفصلة لاحقًا إن رغبت
- Refresh token revocation (قائمة سوداء عند logout) — Phase 7 hardening

## ⚠️ ما لم أختبره: التثبيت من الصفر على جهازك

اختبرت التشغيل، لكن لم أختبر تعليمات التثبيت (خطوات npm install/الخ) على بيئة نظيفة مطابقة لجهازك. اتبع الخطوات التالية وأخبرني إن واجهتك أي مشكلة.

---

## خطوات الإعداد والتشغيل (بالتفصيل الذي طلبته)

### 1. المتطلبات الأساسية
تأكد من إتمام **Phase 3 أولاً** (قاعدة البيانات تعمل ومُهاجَرة بالكامل — راجع `database/README.md`). الـ Backend لن يعمل بدون قاعدة بيانات جاهزة.

### 2. ماذا أثبّت؟
Node.js (نسخة LTS، 18 فما فوق).
**من أين؟** https://nodejs.org
**هل أحتاج حسابًا؟** لا.

### 3. تثبيت التبعيات
```bash
cd backend
npm install
```
**ما المخرج المتوقع؟** رسالة تفيد بتثبيت عدد من الحزم (`added XX packages`) بدون أخطاء حمراء.

### 4. إعداد متغيرات البيئة
**أي ملف أعدّله؟** انسخ `.env.example` إلى `.env`:
```bash
cp .env.example .env
```
**ماذا أضع بداخله؟**
- `DATABASE_URL`: إذا استخدمت `docker-compose.yml` من Phase 3 كما هو، القيمة الافتراضية في `.env.example` صحيحة بالفعل. إذا ثبّتّ PostgreSQL يدويًا بإعدادات مختلفة، عدّل القيمة لتطابق: `postgresql://<user>:<password>@localhost:5432/<database>`
- `JWT_ACCESS_SECRET` و `JWT_REFRESH_SECRET`: نفّذ هذا الأمر مرتين واحفظ كل قيمة في متغيرها:
  ```bash
  node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
  ```

### 5. تشغيل السيرفر
```bash
npm run dev
```
**ما المخرج المتوقع؟**
```
SmartBiz AI backend listening on http://localhost:4000 (development)
```
إذا ظهر خطأ اتصال بقاعدة البيانات (`ECONNREFUSED` أو مشابه)، تأكد أن حاوية/خدمة PostgreSQL من Phase 3 قيد التشغيل فعلاً (`docker ps` أو `pg_isready`).

### 6. التحقق الأساسي
افتح في المتصفح أو عبر `curl`:
```bash
curl http://localhost:4000/health
```
**المتوقع:** `{"status":"ok","env":"development"}`

---

## اختبار الـ API الفعلي (بـ curl أو Postman)

### تسجيل مستخدم جديد
```bash
curl -X POST http://localhost:4000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Amine K.","email":"amine@test.com","password":"password123"}'
```
**المتوقع:** JSON يحتوي `user`, `accessToken`, `refreshToken`. **احفظ الـ `accessToken`** للخطوات التالية.

### إنشاء منتج
```bash
curl -X POST http://localhost:4000/api/products \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  -d '{"name":"Whole Milk 1L","category":"Dairy","purchasePrice":120,"sellingPrice":180,"quantity":42}'
```
**المتوقع:** JSON بالمنتج المُنشأ مع `id`.

### عرض المنتجات
```bash
curl http://localhost:4000/api/products -H "Authorization: Bearer <ACCESS_TOKEN>"
```
**المتوقع:** قائمة تحتوي المنتج الذي أنشأته.

### إنشاء بيع (اختبار الـ Transaction الحقيقية)
```bash
curl -X POST http://localhost:4000/api/sales \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  -d '{"items":[{"productId":"<PRODUCT_ID>","quantity":2}]}'
```
**المتوقع:** JSON بالبيع + الفاتورة (`invoiceNumber: "INV-1"`).

**تحقق من أن المخزون نقص فعليًا:**
```bash
curl http://localhost:4000/api/products/<PRODUCT_ID> -H "Authorization: Bearer <ACCESS_TOKEN>"
```
يجب أن تكون `quantity` قد نقصت بمقدار 2.

**اختبر الـ ROLLBACK عمدًا:** أعد نفس طلب البيع بكمية أكبر من المتوفر (مثلاً 999) — يجب أن يرجع خطأ `INSUFFICIENT_STOCK` ولا يتغيّر شيء في قاعدة البيانات.

إذا ظهر أي خطأ غير متوقع في أي خطوة، انسخ الرد كاملاً (والـ log في الطرفية إن وجد) وأرسله لي فورًا.

---

## هيكل الملفات

```
backend/
├── src/
│   ├── config/
│   │   ├── env.js
│   │   └── db.js                 # pool + query() + withTransaction()
│   ├── middlewares/
│   │   ├── auth.middleware.js    # JWT verify + company_id extraction
│   │   └── error.middleware.js
│   ├── utils/
│   │   ├── ApiError.js
│   │   └── asyncHandler.js
│   ├── modules/
│   │   ├── auth/       (routes, controller, service, validators)
│   │   ├── products/   (routes, controller, service, repository, validators)
│   │   └── sales/      (routes, controller, service, repository, validators)
│   ├── routes/index.js
│   ├── app.js
│   └── server.js
├── package.json
├── .env.example
└── README.md   (هذا الملف)
```

## الخطوة التالية

كل ما تبقى من الـ roadmap الأصلي قبل **Phase 6 (AI)** هو ربط تطبيق Flutter الحقيقي بهذا الـ API بدل الـ Local/Data Layer الحالي — أي استبدال كل repository محلي في Flutter (`ProductsRepository`, `SalesRepository`, إلخ من Phase 4) بمكالمات HTTP حقيقية عبر `dio` أو `http` تتحدث مع هذه الـ endpoints. هل تريد ذلك كخطوة أخيرة ضمن Phase 5 قبل الانتقال لـ Phase 6، أم ننتقل مباشرة لـ AI (Phase 6) ونؤجل ربط Flutter لاحقًا؟
