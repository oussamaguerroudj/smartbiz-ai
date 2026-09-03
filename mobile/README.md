# SmartBiz AI — Mobile (Flutter)

## 🆕 Phase 4 — COMPLETE (all remaining screens + localization infra)

This batch finishes everything that was still outstanding from Phase 4:

### شاشات جديدة كاملة ومربوطة ببيانات حقيقية
- **Invoices**: List + Details (تُقرأ تلقائيًا من كل عملية بيع تُنشأ في Sales)
- **Expenses**: List + Add (مع إجمالي الشهر الحالي محسوب فعليًا)
- **Employees**: List + Add + Details (حضور + راتب صافٍ محسوب: Base + Bonus − Deduction، طبق الصيغة في Ch. 17.3)
- **Appointments**: List/Calendar-style + Create + تحديث الحالة (Completed/Cancelled)
- **Customers** و **Suppliers**: List + Add لكل منهما
- **Notifications**: **مُشتقّة من بيانات حقيقية فعليًا** (Low Stock + Unpaid Invoices) وليست بيانات وهمية — التزامًا بمبدأ عدم اختلاق معلومات
- **Reports**: تجميع حقيقي (Daily/Weekly/Monthly/Yearly) من المبيعات والمصاريف الفعلية؛ زر تصدير PDF/Excel يوضّح أنه يحتاج الـ Backend (Phase 5/8)
- **Settings**: تبديل Theme (Light/Dark/System) ولغة (AR/EN/FR) **يعملان فعليًا** الآن عبر Riverpod providers؛ Business Profile ما زال معطّلاً بانتظار Auth API حقيقي (Phase 5)
- **AI Invoice Scanner**: تدفق كامل (Scan → Processing → Results → Review) — الاستخراج **مُحاكى** (mock) وليس OpenAI حقيقي بعد (Phase 6)، لكن **بوابة المراجعة والتأكيد الإلزامية قبل أي كتابة في المخزون مُطبَّقة فعليًا** كما يتطلب Ch. 15.2
- **AI Assistant (Chat)**: كل رقم في الإجابات **محسوب حقيقيًا** من الـ repositories (وليس رقمًا مكتوبًا يدويًا) — التزامًا الصارم بقاعدة "AI MUST NEVER INVENT FINANCIAL NUMBERS"، حتى في هذه المرحلة المحاكاة
- **AI Insights**: نفس المبدأ — كل insight مشتق من استعلام حقيقي

### البنية التحتية للـ Localization
- `flutter_localizations` أُضيفت، و**RTL الحقيقي يعمل الآن**: تبديل اللغة لـ "العربية" من Settings يقلب اتجاه التطبيق فعليًا (Directionality) عبر `Locale`.
- ⚠️ **لم يُنجز بعد**: استبدال كل النصوص المكتوبة يدويًا (hardcoded English) بمكالمات `AppLocalizations.of(context)` الفعلية عبر جميع الشاشات الـ25+. ملفات `.arb` (AR/EN/FR) جاهزة في `core/localization/`، لكن ربطها الكامل عبر كل شاشة يحتاج دفعة مراجعة منفصلة (سيتم لاحقًا إذا رغبت، أو ضمن Phase 7 Polish).

### Main Shell محدَّث بالكامل
قائمة **More** الآن تفتح كل شاشة حقيقية (لم تعد `onTap: () {}` فارغة).

### ⚠️ اختبار هذه الدفعة
```
flutter pub get
flutter analyze
flutter run
```
جرّب: إضافة مصروف → Reports يعكسه فورًا. أنشئ بيع → Invoices يعرضه تلقائيًا. امسح فاتورة تجريبية (AI Scanner) → راجع العناصر → أكّد → Inventory يعرض المنتجات الجديدة. اسأل AI Assistant "How much did I earn this month?" وقارن الرقم مع Dashboard — يجب أن يتطابقا لأنهما من نفس المصدر الحقيقي. بدّل اللغة لعربي من Settings — يجب أن ينقلب اتجاه الشاشة بالكامل.

إذا ظهر أي خطأ، أرسل النص الكامل لأصلحه فورًا.

---

## Phase 4, Batch 1 — Local/Data Layer + Inventory + Sales

### ما تم إضافته في هذه الدفعة
- **Local/Data Layer** عبر Riverpod (`flutter_riverpod` أُضيفت إلى `pubspec.yaml`):
  - `ProductsRepository` — بيانات تجريبية مطابقة تمامًا لـ seed الخاص بـ Phase 3 (نفس المنتجات والكميات).
  - `SalesRepository` + `InvoicesRepository` — ينفذان تسلسل خطوات "Create Sale" من Ch. 11.2 حرفيًا: التحقق من كامل توفر المخزون **قبل** أي كتابة، ثم خصم المخزون، ثم إنشاء البيع، ثم إنشاء الفاتورة — أي فشل في التحقق لا يغيّر أي شيء (المعادل المحلي لـ Database Transaction + ROLLBACK المطلوب في الـ Spec).
- **Products (Inventory) حقيقية بالكامل:** Products List (بحث + مؤشرات لون للمخزون) → Add Product (validation حسب جدول Ch. 10.2، بما فيه تحذير "selling price below purchase" كتحذير غير معطّل) → Product Details (هامش ربح، سعر شراء/بيع محسوبان).
- **Sales حقيقية بالكامل:** Sales List (بيانات حقيقية من الـ repository) → Create Sale (اختيار منتج عبر bottom sheet، عربة تسوق بكميات قابلة للتعديل، خصم، حساب المجموع، تأكيد البيع مع معالجة خطأ نفاد المخزون).
- **Dashboard مُحدَّث:** الآن يعرض أرقامًا حقيقية (Today Revenue/Profit/Sales Count/Low Stock) من الـ repositories بدل الرموز الفارغة `—`. حقل Expenses ما زال `—` عمدًا لأن ميزة Expenses لم تُبنَ بعد (لتفادي عرض رقم غير حقيقي).
- Main Shell الآن يعرض الشاشات الحقيقية بدل placeholders في تبويبي Sales وInventory.

### لم يُبنَ بعد (دفعات Phase 4 القادمة)
Invoices (List/Details/PDF)، Expenses، Employees/Attendance/Salaries، Appointments، Customers/Suppliers، Notifications، Reports، Settings، شاشات AI، وربط RTL/localization فعليًا.

### ⚠️ اختبار هذه الدفعة
1. بعد فك الضغط، **احذف `pubspec.lock` القديم إن وجد** (لإضافة تبعية `flutter_riverpod` الجديدة بشكل صحيح)، ثم من داخل `mobile/`:
   ```
   flutter pub get
   flutter analyze
   flutter run
   ```
2. سجّل الدخول كالمعتاد حتى تصل للشاشة الرئيسية.
3. تبويب **Inventory**: يجب أن ترى 4 منتجات (Whole Milk 1L: 42، Baguette Bread: 5 — Low stock، Sugar 1kg: 60، Olive Oil 1L: 0 — Out of stock) — مطابقة تمامًا لأمثلة الـ Spec وseed الـ Phase 3.
4. اضغط + لإضافة منتج جديد، جرّب حفظ سعر بيع أقل من سعر الشراء — يجب أن يظهر تحذير أحمر بدون منع الحفظ.
5. تبويب **Sales**: اضغط + لإنشاء بيع جديد، اختر منتجًا (جرّب Olive Oil 1L — يجب أن يظهر "Out of stock" ولا يمكن اختياره)، اختر Whole Milk 1L بكمية 2، أكّد البيع.
6. ارجع لتبويب Inventory — يجب أن تجد كمية Whole Milk 1L قد نقصت بمقدار 2 تلقائيًا.
7. اذهب لتبويب Dashboard — يجب أن تظهر Today Revenue وProfit وSales Count محدّثة بالبيع الذي أنشأته للتو.

إذا ظهر أي خطأ في أي خطوة، انسخ رسالة الخطأ كاملة وأرسلها لي.

---

# SmartBiz AI — Mobile (Flutter) — Phase 2, Batch 1

هذا هو أول دفعة من **Phase 2 (Complete Flutter UI/UX + Design System + Navigation)**.

## ما تم إنجازه في هذه الدفعة

- ✅ Design System كامل: ألوان (`app_colors.dart`)، طباعة (`app_typography.dart`)، تباعد (`app_spacing.dart`)، ThemeData فاتح/داكن (`app_theme.dart`)
- ✅ ملفات الترجمة الأولية (AR/EN/FR) بصيغة `.arb` — جاهزة للربط بـ `flutter_localizations`
- ✅ تدفق Onboarding/Authentication كامل بشاشات حقيقية:
  - Splash
  - Onboarding (3 شرائح)
  - Login
  - Register
  - Business Type Selection (مع تعريف `BusinessType` enum الذي سيقود لاحقًا مصفوفة الميزات)
  - Business Setup
- ✅ Main Shell: Bottom Navigation (Dashboard/Sales/Inventory/More) + قائمة More الكاملة
- ✅ Dashboard: تخطيط ثابت (KPI cards, chart placeholder, quick action) — **بدون بيانات حقيقية بعد** (تُربط في Phase 4/5)
- ✅ `main.dart` يربط كل الشاشات في تدفق تنقّل كامل وقابل للتجربة من البداية للنهاية

## ما لم يتم بعد (الدفعات القادمة ضمن Phase 2)

- شاشات Inventory الكاملة (Products List/Add/Details/Low-Stock)
- شاشات Sales الكاملة (List/Create/Confirmation)
- شاشات Invoices (List/Details/PDF Preview)
- شاشات AI (Scanner/Processing/Results/Review/Chat/Insights)
- شاشات Employees/Attendance/Salaries
- شاشات Appointments/Calendar
- Notifications, Customers, Suppliers, Reports, Settings
- ربط `flutter_localizations` فعليًا + اختبار RTL كامل
- استبدال Navigator يدوي بـ `go_router` مع route guards

**سأنتظر مراجعتك لهذه الدفعة قبل بناء بقية الشاشات، حتى تتأكد أن الاتجاه (Design System + Navigation Pattern) يعجبك قبل تكراره على 25+ شاشة أخرى.**

---

## ⚠️ ملاحظة مهمة حول بيئة التنفيذ

لا أملك في هذه البيئة (sandbox المحادثة) اتصالاً بـ `pub.dev` ولا Flutter SDK مثبّت، لذلك **لم أتمكن من تشغيل `flutter pub get` أو `flutter analyze` أو `flutter run` هنا**. الكود مكتوب يدويًا باتباع Flutter/Dart syntax القياسي، لكن يجب أن تُشغّله وتتحقق منه على جهازك. اتبع الخطوات التالية بالضبط:

### 1. ما الذي أثبّته؟
Flutter SDK (يتضمن Dart SDK تلقائيًا).

### 2. من أين أحصل عليه؟
من الموقع الرسمي: https://docs.flutter.dev/get-started/install
اختر نظام التشغيل لديك (Windows / macOS / Linux).

### 3. هل أحتاج حسابًا؟
لا، تثبيت Flutter SDK لا يتطلب أي حساب. (لاحقًا ستحتاج حساب Google Play Console / Apple Developer فقط عند النشر، وهذا في Phase 8).

### 4. أين أُنشئه؟
لا ينطبق في هذه الخطوة.

### 5. ما الذي أُعدّه بالضبط؟
بعد التثبيت، شغّل الأمر التالي للتأكد أن كل شيء سليم:
```
flutter doctor
```
تأكد أن Android Studio (أو Xcode لـ macOS) مثبّت أيضًا كما يوجّهك `flutter doctor`.

### 6. أي ملف أعدّله؟
لا حاجة لتعديل أي ملف في هذه الخطوة — فقط انسخ مجلد `mobile/` كاملاً كما هو إلى جهازك.

### 7. ماذا أضع بداخله؟
لا شيء إضافي الآن. المجلد جاهز كما هو.

### 8. أي أمر أُشغّله؟
من داخل مجلد `mobile/`:
```
flutter pub get
flutter analyze
flutter run
```

### 9. ما هو المُخرج المتوقع؟
- `flutter pub get`: يجب أن ينتهي بدون أخطاء ويُنشئ ملف `pubspec.lock`.
- `flutter analyze`: يجب أن يعرض `No issues found!` (إذا ظهرت تحذيرات بسيطة أخبرني وسأصلحها).
- `flutter run`: يفتح المحاكي/الجهاز ويعرض شاشة Splash خضراء، ثم ينتقل تلقائيًا لـ Onboarding، ثم يمكنك تجربة كامل تدفق Login → Register → Business Type → Business Setup → Dashboard الرئيسي مع Bottom Navigation.

### 10. كيف أتحقق أن كل شيء يعمل؟
جرّب بالترتيب:
1. شاهد Splash خضراء لحظيًا ثم انتقال تلقائي.
2. مرّر بين شرائح Onboarding الثلاث، اضغط "Get Started".
3. في شاشة Login اضغط "Login" بدون تعبئة الحقول — يجب أن تظهر رسائل خطأ حمراء تحت الحقول.
4. عبّئ بريدًا وكلمة مرور صحيحين، اضغط Login — يجب الانتقال مباشرة إلى الشاشة الرئيسية (Dashboard مع Bottom Nav).
5. جرّب التبديل بين تبويبات Dashboard/Sales/Inventory/More، وتصفح قائمة More.

إذا نفّذت الخطوات أعلاه وظهرت أي رسالة خطأ في الطرفية (terminal)، انسخها وأرسلها لي وسأصلحها فورًا — هذا هو دور مرحلة **Test → Fix** التي التزمنا بها.

---

## هيكل الملفات في هذه الدفعة

```
mobile/
├── lib/
│   ├── core/
│   │   ├── theme/            # design tokens (colors, typography, spacing, ThemeData)
│   │   ├── localization/     # app_en.arb, app_ar.arb, app_fr.arb
│   │   └── widgets/          # app_text_field.dart (shared component)
│   ├── features/
│   │   ├── onboarding/presentation/screens/  # splash, onboarding
│   │   ├── auth/presentation/screens/        # login, register, business type, business setup
│   │   ├── dashboard/presentation/screens/   # dashboard (static layout)
│   │   └── shell/presentation/               # main_shell.dart (bottom nav + more menu)
│   └── main.dart
├── pubspec.yaml
└── README.md   (هذا الملف)
```
