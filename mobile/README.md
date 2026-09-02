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
