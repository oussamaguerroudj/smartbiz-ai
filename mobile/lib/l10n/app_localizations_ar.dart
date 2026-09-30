// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'Modiri AI';

  @override
  String get onboardingTitle1 => 'أدر عملك بسهولة';

  @override
  String get onboardingDesc1 =>
      'تابع المبيعات والمخزون والأرباح من مكان واحد، من هاتفك.';

  @override
  String get onboardingTitle2 => 'تتبّع مخزونك';

  @override
  String get onboardingDesc2 =>
      'لا تنفد كميتك أبدًا — احصل على تنبيهات قبل نفاد المنتجات.';

  @override
  String get onboardingTitle3 => 'اعمل بذكاء مع الذكاء الاصطناعي';

  @override
  String get onboardingDesc3 =>
      'امسح فواتير الموردين واسأل مساعدك الذكي عن نشاطك التجاري.';

  @override
  String get skip => 'تخطي';

  @override
  String get next => 'التالي';

  @override
  String get getStarted => 'ابدأ الآن';

  @override
  String get loginTitle => 'مرحبًا بعودتك';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get rememberMe => 'تذكرني';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get noAccount => 'ليس لديك حساب؟ سجّل الآن';

  @override
  String get registerTitle => 'إنشاء حساب';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get createAccount => 'إنشاء الحساب';

  @override
  String get haveAccount => 'لديك حساب بالفعل؟ سجّل الدخول';

  @override
  String get selectBusinessType => 'اختر نوع النشاط';

  @override
  String stepOf(Object current, Object total) {
    return 'الخطوة $current من $total';
  }

  @override
  String get chooseBusinessTypeHint => 'اختر الخيار الأنسب لنشاطك التجاري';

  @override
  String get businessTypeClothing => 'متجر ملابس';

  @override
  String get businessTypeClothingDesc => 'مقاسات، ألوان، باركود';

  @override
  String get businessTypeGrocery => 'سوق / متجر';

  @override
  String get businessTypeGroceryDesc =>
      'سوبر ماركت، ميني ماركت، بقالة، متجر عام';

  @override
  String get businessTypePharmacy => 'صيدلية';

  @override
  String get businessTypePharmacyDesc => 'المخزون، تنبيهات الصلاحية';

  @override
  String get businessTypeClinic => 'عيادة طبية';

  @override
  String get businessTypeClinicDesc => 'المرضى، المواعيد — طبية وأسنان';

  @override
  String get businessTypeRestaurant => 'مطعم / مقهى';

  @override
  String get businessTypeRestaurantDesc =>
      'قائمة الطعام، الطلبات، الطاولات — مطاعم ومقاهي';

  @override
  String get businessTypeCompany => 'مؤسسة / شركة';

  @override
  String get businessTypeCompanyDesc => 'الموظفون، الفواتير';

  @override
  String get businessTypeWorkshop => 'ورشة / حرفي';

  @override
  String get businessTypeWorkshopDesc => 'الطلبات، الخدمات';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get businessSetupTitle => 'إعداد النشاط التجاري';

  @override
  String get businessName => 'اسم النشاط التجاري';

  @override
  String get businessNameHint => 'مثال: بقالة أمين';

  @override
  String get businessTypeLabel => 'نوع النشاط';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get address => 'العنوان';

  @override
  String get addressHint => 'المدينة، الشارع';

  @override
  String get currency => 'العملة';

  @override
  String get finishSetup => 'إنهاء الإعداد';

  @override
  String get navDashboard => 'الرئيسية';

  @override
  String get navSales => 'المبيعات';

  @override
  String get navInventory => 'المخزون';

  @override
  String get navMore => 'المزيد';

  @override
  String get moreInvoices => 'الفواتير';

  @override
  String get moreExpenses => 'المصاريف';

  @override
  String get moreEmployees => 'الموظفون';

  @override
  String get moreAppointments => 'المواعيد';

  @override
  String get moreReports => 'التقارير';

  @override
  String get moreAiAssistant => 'المساعد الذكي';

  @override
  String get moreNotifications => 'الإشعارات';

  @override
  String get moreSettings => 'الإعدادات';

  @override
  String get goodMorning => 'صباح الخير';

  @override
  String get dashboardRevenue => 'الإيرادات';

  @override
  String get dashboardProfit => 'الربح';

  @override
  String get dashboardLowStock => 'مخزون منخفض';

  @override
  String dashboardTodayCurrency(Object currency) {
    return 'اليوم · $currency';
  }

  @override
  String get dashboardToday => 'اليوم';

  @override
  String get dashboardNeedsReview => 'يحتاج مراجعة';

  @override
  String get dashboardAllGood => 'الوضع جيد';

  @override
  String get salesTrend => 'اتجاه المبيعات';

  @override
  String get rangeWeek => 'أسبوع';

  @override
  String get rangeMonth => 'شهر';

  @override
  String get rangeYear => 'سنة';

  @override
  String get newSale => 'بيع جديد';

  @override
  String get scanInvoice => 'مسح فاتورة';

  @override
  String lowStockMessage(Object count) {
    return '$count منتج منخفض المخزون';
  }

  @override
  String get noSalesInPeriod => 'لا توجد مبيعات مسجلة في هذه الفترة بعد';

  @override
  String get verifyAccountTitle => 'تحقق من حسابك';

  @override
  String verifyAccountSubtitle(Object email) {
    return 'أرسلنا رمزًا مكونًا من 6 أرقام إلى $email';
  }

  @override
  String get verifyCodeLabel => 'رمز التحقق';

  @override
  String get verifyEnterFullCode => 'أدخل الرمز المكون من 6 أرقام';

  @override
  String get verifyResendCode => 'إعادة إرسال الرمز';

  @override
  String verifyResendIn(Object seconds) {
    return 'إعادة الإرسال خلال $seconds ثانية';
  }

  @override
  String get verifyCodeResent => 'تم إرسال الرمز';

  @override
  String get verifyAccountButton => 'تحقق';

  @override
  String get backToLogin => 'العودة لتسجيل الدخول';

  @override
  String get networkError => 'تعذر الوصول إلى الخادم — تحقق من اتصالك';

  @override
  String get forgotPasswordTitle => 'نسيت كلمة المرور';

  @override
  String get forgotPasswordSubtitle =>
      'أدخل بريدك الإلكتروني وسنرسل لك رمز إعادة التعيين';

  @override
  String get sendResetCode => 'إرسال رمز إعادة التعيين';

  @override
  String resetPasswordSubtitle(Object email) {
    return 'أدخل الرمز المرسل إلى $email واختر كلمة مرور جديدة';
  }

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get resetPasswordButton => 'إعادة تعيين كلمة المرور';

  @override
  String get useAnotherEmail => 'استخدام بريد إلكتروني آخر';

  @override
  String get passwordResetSuccess =>
      'تمت إعادة تعيين كلمة المرور — الرجاء تسجيل الدخول';

  @override
  String get emailRequired => 'البريد الإلكتروني مطلوب';

  @override
  String get emailInvalid => 'أدخل بريدًا إلكترونيًا صالحًا';

  @override
  String get passwordRequired => 'كلمة المرور مطلوبة';

  @override
  String get passwordTooShort => 'الحد الأدنى 6 أحرف';

  @override
  String get nameRequired => 'أدخل اسمك الكامل';

  @override
  String get passwordsDoNotMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get loginSubtitle => 'سجل الدخول إلى لوحة تحكم عملك';

  @override
  String get yourNameHint => 'اسمك';

  @override
  String get moreTitle => 'المزيد';

  @override
  String get moreCustomers => 'العملاء';

  @override
  String get moreSuppliers => 'الموردون';

  @override
  String get moreAiScanner => 'ماسح الفواتير الذكي';

  @override
  String get moreAiInsights => 'رؤى الذكاء الاصطناعي';

  @override
  String errorPrefix(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get salesEmptyState => 'لا توجد مبيعات بعد — اضغط + لتسجيل واحدة';

  @override
  String saleNumberFallback(Object id) {
    return 'بيع رقم $id';
  }

  @override
  String get walkInCustomer => 'زبون عابر';

  @override
  String saleRowSubtitle(Object customer, Object count) {
    return '$customer · $count عنصر';
  }

  @override
  String get requiredField => 'مطلوب';

  @override
  String get enterValidAmount => 'أدخل مبلغًا صالحًا';

  @override
  String get employeesTitle => 'الموظفون';

  @override
  String get addEmployee => 'إضافة موظف';

  @override
  String get saveEmployee => 'حفظ الموظف';

  @override
  String get positionLabel => 'المنصب';

  @override
  String get baseSalaryLabel => 'الراتب الأساسي';

  @override
  String get staffDefault => 'موظف';

  @override
  String get employeeFallback => 'موظف';

  @override
  String get attendancePresent => 'حاضر';

  @override
  String get attendanceAbsent => 'غائب';

  @override
  String get attendanceLate => 'متأخر';

  @override
  String get salaryThisMonth => 'راتب هذا الشهر';

  @override
  String baseSalaryValue(Object amount) {
    return 'الأساسي: $amount';
  }

  @override
  String get markPresent => 'تسجيل حضور';

  @override
  String get markAbsent => 'تسجيل غياب';

  @override
  String get invoicesTitle => 'الفواتير';

  @override
  String get noInvoicesYet => 'لا توجد فواتير بعد';

  @override
  String get statusUnpaid => 'غير مدفوعة';

  @override
  String get statusPaid => 'مدفوعة';

  @override
  String get invoiceFallback => 'فاتورة';

  @override
  String get billTo => 'يُفوتر إلى';

  @override
  String get itemsLabel => 'العناصر';

  @override
  String get totalLabel => 'المجموع';

  @override
  String lineItemLabel(Object name, Object qty) {
    return '$name × $qty';
  }

  @override
  String get pdfExportNotImplemented =>
      'تصدير PDF: نقطة النهاية موجودة لكن لم تُنفَّذ بعد';

  @override
  String get shareViaWhatsapp => 'مشاركة عبر واتساب';

  @override
  String balanceDue(Object amount) {
    return 'مستحق $amount دج';
  }

  @override
  String get noBalanceDue => 'لا يوجد مستحق';

  @override
  String get addCustomer => 'إضافة عميل';

  @override
  String get saveCustomer => 'حفظ العميل';

  @override
  String get nameLabel => 'الاسم';

  @override
  String get phoneLabel => 'الهاتف';

  @override
  String productsSuppliedCount(Object count) {
    return 'يورّد $count منتج';
  }

  @override
  String get addSupplier => 'إضافة مورد';

  @override
  String get saveSupplier => 'حفظ المورد';

  @override
  String get expensesTitle => 'المصروفات';

  @override
  String get thisMonthTotal => 'إجمالي هذا الشهر';

  @override
  String get noExpensesYet => 'لم يتم تسجيل أي مصروفات بعد';

  @override
  String get addExpense => 'إضافة مصروف';

  @override
  String get saveExpense => 'حفظ المصروف';

  @override
  String get categoryLabel => 'الفئة';

  @override
  String get descriptionLabel => 'الوصف';

  @override
  String get optionalNoteHint => 'ملاحظة اختيارية';

  @override
  String get amountDzdLabel => 'المبلغ (دج)';

  @override
  String get noNotifications => 'لا توجد إشعارات — كل شيء على ما يرام';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get businessProfileTitle => 'ملف الشركة';

  @override
  String get businessProfileSubtitle =>
      'إدارة البيانات الشخصية ومعلومات النشاط';

  @override
  String get businessProfileSnack =>
      'يتم تعيين ملف الشركة أثناء الإعداد الأولي — ستتوفر شاشة للتعديل لاحقًا';

  @override
  String get currencyTitle => 'العملة';

  @override
  String get themeTitle => 'المظهر';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeSystem => 'النظام';

  @override
  String get languageTitle => 'اللغة';

  @override
  String get aiSettingsTitle => 'إعدادات الذكاء الاصطناعي';

  @override
  String get aiSettingsSubtitle => 'حدود الاستخدام — المرحلة 6';

  @override
  String get logoutTitle => 'تسجيل الخروج';

  @override
  String get logoutConfirm => 'هل أنت متأكد أنك تريد تسجيل الخروج؟';

  @override
  String get cancel => 'إلغاء';

  @override
  String get setupSaveFailedTitle => 'تعذر حفظ الإعداد';

  @override
  String get ok => 'موافق';

  @override
  String productsTitleCount(Object count) {
    return 'المنتجات · $count';
  }

  @override
  String get productsTitle => 'المنتجات';

  @override
  String get searchProductsHint => 'ابحث عن المنتجات...';

  @override
  String get noProductsFound => 'لم يتم العثور على منتجات';

  @override
  String get qtyOutOfStock => 'الكمية: 0 — نفد المخزون';

  @override
  String qtyLowStock(Object qty) {
    return 'الكمية: $qty — مخزون منخفض';
  }

  @override
  String qtyOnly(Object qty) {
    return 'الكمية: $qty';
  }

  @override
  String get productNotFound => 'المنتج غير موجود';

  @override
  String get inStockLabel => 'متوفر بالمخزون';

  @override
  String get marginLabel => 'هامش الربح';

  @override
  String get pricingLabel => 'التسعير';

  @override
  String purchasePriceValue(Object amount) {
    return 'الشراء: $amount دج';
  }

  @override
  String sellingPriceValue(Object amount) {
    return 'البيع: $amount دج';
  }

  @override
  String profitPerUnitValue(Object amount) {
    return 'الربح/الوحدة: $amount دج';
  }

  @override
  String get categoryLabelTitle => 'الفئة';

  @override
  String get enterValidNumber => 'أدخل رقمًا صالحًا';

  @override
  String get mustBeNonNegative => 'يجب أن يكون ≥ 0';

  @override
  String get uncategorized => 'غير مصنف';

  @override
  String get addProductTitle => 'إضافة منتج';

  @override
  String get productNameLabel => 'اسم المنتج';

  @override
  String get productNameHint => 'مثال: حليب كامل الدسم 1 لتر';

  @override
  String get categoryHint => 'الألبان';

  @override
  String get purchasePriceLabel => 'سعر الشراء (دج)';

  @override
  String get sellingPriceLabel => 'سعر البيع (دج)';

  @override
  String get sellingBelowPurchaseWarning => '⚠ سعر البيع أقل من سعر الشراء';

  @override
  String get quantityLabel => 'الكمية';

  @override
  String get enterValidInteger => 'أدخل عددًا صحيحًا صالحًا ≥ 0';

  @override
  String get saveProduct => 'حفظ المنتج';

  @override
  String get appointmentsTitle => 'المواعيد';

  @override
  String get noAppointmentsScheduled => 'لا توجد مواعيد مجدولة';

  @override
  String get markCompleted => 'وضع علامة مكتمل';

  @override
  String get cancelAppointment => 'إلغاء';

  @override
  String appointmentTimeName(Object time, Object name) {
    return '$time — $name';
  }

  @override
  String get newAppointmentTitle => 'موعد جديد';

  @override
  String get patientCustomerLabel => 'المريض / العميل';

  @override
  String timeLabel(Object time) {
    return 'الوقت: $time';
  }

  @override
  String get notesLabel => 'ملاحظات';

  @override
  String get optionalHint => 'اختياري';

  @override
  String get saveAppointment => 'حفظ الموعد';

  @override
  String get reportsTitle => 'التقارير';

  @override
  String get periodDaily => 'يومي';

  @override
  String get periodWeekly => 'أسبوعي';

  @override
  String get periodMonthly => 'شهري';

  @override
  String get periodYearly => 'سنوي';

  @override
  String get exportAsPdf => 'تصدير كملف PDF';

  @override
  String get exportAsExcel => 'تصدير كملف إكسل';

  @override
  String get exportComingSoon => 'تصدير PDF/إكسل سيتوفر في تحديث قادم';

  @override
  String get aiInsightsTitle => 'رؤى الذكاء الاصطناعي';

  @override
  String get notEnoughDataForInsights => 'لا توجد بيانات كافية لتوليد رؤى بعد';

  @override
  String get scanInvoiceTitle => 'مسح الفاتورة';

  @override
  String get pointCameraAtInvoice => 'وجّه الكاميرا نحو الفاتورة';

  @override
  String get keepInvoiceFlatWellLit =>
      'حافظ على استواء الفاتورة وإضاءتها جيدًا';

  @override
  String get cameraButton => 'الكاميرا';

  @override
  String get chooseFromGallery => 'اختر من المعرض';

  @override
  String get tryDemoInvoice => '▶ جرّب فاتورة تجريبية';

  @override
  String get analyzingInvoice => 'جارٍ تحليل الفاتورة...';

  @override
  String get readingTextDetecting => 'قراءة النص، اكتشاف المنتجات والكميات';

  @override
  String get detectedItemsTitle => 'العناصر المكتشفة';

  @override
  String qtyValue(Object qty) {
    return 'الكمية: $qty';
  }

  @override
  String get reviewAndEdit => 'مراجعة وتعديل';

  @override
  String get reviewItemsTitle => 'مراجعة العناصر';

  @override
  String get productNameFieldLabel => 'اسم المنتج';

  @override
  String get quantityFieldLabel => 'الكمية';

  @override
  String get purchasePriceFieldLabel => 'سعر الشراء';

  @override
  String get confirmAddToInventory => 'تأكيد والإضافة إلى المخزون';

  @override
  String productsAddedToInventory(Object count) {
    return 'تمت إضافة $count منتج إلى المخزون';
  }

  @override
  String get noProductsLoadedYet =>
      'لم يتم تحميل أي منتجات بعد — تحقق من اتصالك وأعد المحاولة';

  @override
  String onlyNInStock(Object qty, Object name) {
    return 'يوجد $qty فقط في المخزون لـ $name';
  }

  @override
  String outOfStockFor(Object name) {
    return '$name نفد من المخزون';
  }

  @override
  String get addAtLeastOneProduct => 'أضف منتجًا واحدًا على الأقل إلى السلة';

  @override
  String get saleRecordedSuccessfully => 'تم تسجيل البيع بنجاح';

  @override
  String couldNotCompleteSale(Object error) {
    return 'تعذر إتمام البيع: $error';
  }

  @override
  String get newSaleTitle => 'بيع جديد';

  @override
  String get searchProductOrScan => 'ابحث عن منتج أو امسح الباركود';

  @override
  String get scanInvoiceChooserTitle => 'أي فاتورة تريد مسحها؟';

  @override
  String get scanSalesInvoiceOption => 'فاتورة بيع';

  @override
  String get scanSalesInvoiceSubtitle => 'تسجيل عملية بيع من إيصال العميل';

  @override
  String get scanStockInvoiceOption => 'فاتورة مخزون';

  @override
  String get scanStockInvoiceSubtitle => 'إضافة العناصر المشتراة إلى المخزون';

  @override
  String get scanBarcodeTooltip => 'مسح الباركود';

  @override
  String get barcodeScannerTitle => 'مسح الباركود';

  @override
  String get barcodeScannerHint => 'ضع الباركود داخل الإطار';

  @override
  String get enterCodeManually => 'إدخال الرمز يدويًا';

  @override
  String get manualBarcodeEntryTitle => 'إدخال الباركود';

  @override
  String barcodeNotFoundMessage(Object code) {
    return 'لا يوجد منتج مطابق للباركود $code';
  }

  @override
  String get addAsNewProductAction => 'إضافة كمنتج جديد';

  @override
  String scannedProductAddedToCart(Object name) {
    return 'تمت إضافة $name إلى السلة';
  }

  @override
  String get matchProductLabel => 'المنتج المطابق';

  @override
  String get selectProductHint => 'اختر منتجًا';

  @override
  String get salesInvoiceReviewTitle => 'مراجعة عناصر البيع';

  @override
  String get confirmRecordSale => 'تأكيد وتسجيل البيع';

  @override
  String get saleRecordedFromScan => 'تم تسجيل البيع من الفاتورة الممسوحة';

  @override
  String get pleaseMatchAllItems => 'قم بمطابقة كل عنصر مع منتج قبل المتابعة';

  @override
  String get cameraPermissionRequired => 'إذن الكاميرا مطلوب للمسح';

  @override
  String get noMatchFound => 'لا توجد مطابقة — اختر يدويًا';

  @override
  String get unitPriceLabel => 'سعر الوحدة';

  @override
  String get removeItemLabel => 'إزالة';

  @override
  String get barcodeFieldLabel => 'الباركود (اختياري)';

  @override
  String get barcodeFieldHint => 'امسح أو أدخل يدويًا';

  @override
  String get noItemsDetected =>
      'لم يتم العثور على أي عناصر في هذه الصورة — حاول مرة أخرى بإضاءة أفضل.';

  @override
  String get expensePeriodTypeLabel => 'نوع الفترة';

  @override
  String get periodOneTime => 'مرة واحدة';

  @override
  String get periodCustom => 'مخصص';

  @override
  String get periodStartLabel => 'من';

  @override
  String get periodEndLabel => 'إلى';

  @override
  String expenseCoversDays(Object days) {
    return 'يغطي $days يوم';
  }

  @override
  String get selectPeriodEndDate =>
      'الرجاء اختيار تاريخ نهاية لهذه الفترة المخصصة';

  @override
  String get selectCustomerFirst => 'الرجاء اختيار الزبون أولاً';

  @override
  String get noCustomersYet => 'لا يوجد زبائن بعد — أضف واحدًا أولاً';

  @override
  String get amountExceedsTotal => 'المبلغ المدفوع لا يمكن أن يتجاوز الإجمالي';

  @override
  String get creditSaleTitle => 'عملية بيع بالدين جديدة';

  @override
  String get selectCustomerHint => 'اختر زبونًا';

  @override
  String get amountToPayNowLabel => 'المبلغ المدفوع الآن (دج)';

  @override
  String get remainingCreditLabel => 'الدين المتبقي';

  @override
  String get confirmCreditSaleButton => 'تأكيد عملية البيع بالدين';

  @override
  String get creditSaleRecorded => 'تم تسجيل عملية البيع بالدين';

  @override
  String get creditPageTitle => 'الديون';

  @override
  String get newCreditSaleAction => 'عملية بيع بالدين جديدة';

  @override
  String get customersWithCreditTitle => 'الزبائن الذين عليهم ديون';

  @override
  String get noOutstandingCredit => 'لا يوجد أي زبون عليه دين حاليًا';

  @override
  String get totalCreditLabel => 'إجمالي الدين';

  @override
  String get totalPaidLabel => 'المدفوع';

  @override
  String get noOutstandingBalanceForCustomer =>
      'لا يوجد رصيد مستحق على هذا الزبون';

  @override
  String get recordPaymentTitle => 'تسجيل دفعة';

  @override
  String currentBalanceHelper(Object balance) {
    return 'الرصيد الحالي: $balance دج';
  }

  @override
  String get paymentRecorded => 'تم تسجيل الدفعة';

  @override
  String get noTransactionsYet => 'لا توجد معاملات بعد';

  @override
  String get creditPurchaseLabel => 'عملية بيع بالدين';

  @override
  String get paymentLabel => 'دفعة';

  @override
  String balanceAfterLabel(Object balance) {
    return 'الرصيد بعد العملية: $balance دج';
  }

  @override
  String get clinicDashboardTitle => 'لوحة تحكم العيادة';

  @override
  String get patientsTodayLabel => 'المرضى اليوم';

  @override
  String get appointmentsTodayLabel => 'المواعيد اليوم';

  @override
  String get waitingLabel => 'في الانتظار';

  @override
  String get completedTodayLabel => 'تمت معاينتهم اليوم';

  @override
  String get noShowTodayLabel => 'لم يحضروا اليوم';

  @override
  String get newPatientsTodayLabel => 'مرضى جدد اليوم';

  @override
  String get doctorsLabel => 'الأطباء';

  @override
  String get clinicQueueTitle => 'قائمة الانتظار';

  @override
  String get callNextPatientButton => 'استدعاء المريض التالي';

  @override
  String nextPatientLabel(Object name) {
    return 'المريض التالي: $name';
  }

  @override
  String get noOneWaitingMessage => 'لا يوجد أحد ينتظر حاليًا';

  @override
  String get completeConsultationButton => 'إنهاء المعاينة';

  @override
  String get clinicPatientsTitle => 'المرضى';

  @override
  String get addPatientTitle => 'إضافة مريض';

  @override
  String get fullNameLabel => 'الاسم الكامل';

  @override
  String get genderLabel => 'الجنس';

  @override
  String get dateOfBirthLabel => 'تاريخ الميلاد';

  @override
  String get savePatient => 'حفظ المريض';

  @override
  String get patientProfileTitle => 'ملف المريض';

  @override
  String get visitHistoryTitle => 'سجل الزيارات';

  @override
  String get noVisitsYetMessage => 'لا توجد زيارات مسجلة بعد';

  @override
  String get diagnosisLabel => 'التشخيص';

  @override
  String get treatmentLabel => 'العلاج';

  @override
  String get prescriptionLabel => 'الوصفة الطبية';

  @override
  String get followUpDateLabel => 'تاريخ المتابعة';

  @override
  String get addToQueueAction => 'إضافة إلى قائمة الانتظار';

  @override
  String get selectPatientTitle => 'اختر مريضًا';

  @override
  String get searchPatientsHint => 'البحث عن المرضى...';

  @override
  String get noPatientsFoundMessage => 'لم يتم العثور على مرضى';

  @override
  String get delete => 'حذف';

  @override
  String get documentsTitle => 'الوثائق الطبية';

  @override
  String get addDocumentAction => 'إضافة وثيقة';

  @override
  String get documentNameLabel => 'اسم الوثيقة';

  @override
  String get documentTypeLabel => 'نوع الوثيقة';

  @override
  String get fileUrlLabel => 'رابط الملف';

  @override
  String get noDocumentsYetMessage => 'لا توجد وثائق بعد';

  @override
  String get confirmDeleteDocumentMessage => 'هل تريد حذف هذه الوثيقة؟';

  @override
  String get documentDeletedMessage => 'تم حذف الوثيقة';

  @override
  String get documentAddedMessage => 'تمت إضافة الوثيقة';

  @override
  String get prescriptionsTitle => 'الوصفات الطبية';

  @override
  String get newPrescriptionAction => 'وصفة جديدة';

  @override
  String get noPrescriptionsYetMessage => 'لا توجد وصفات بعد';

  @override
  String get medicationNameLabel => 'اسم الدواء';

  @override
  String get dosageLabel => 'الجرعة';

  @override
  String get frequencyLabel => 'التكرار';

  @override
  String get durationLabel => 'المدة';

  @override
  String get instructionsLabel => 'التعليمات';

  @override
  String get addMedicationAction => 'إضافة دواء';

  @override
  String get savePrescriptionAction => 'حفظ الوصفة';

  @override
  String get prescriptionSavedMessage => 'تم حفظ الوصفة';

  @override
  String get prescriptionNumberLabel => 'رقم الوصفة';

  @override
  String get medicationRequiredMessage => 'يلزم دواء واحد على الأقل';

  @override
  String get patientAddedMessage => 'تمت إضافة المريض';

  @override
  String get queueEmptyMessage => 'قائمة الانتظار فارغة';

  @override
  String get consultationPriceLabel => 'سعر الاستشارة';

  @override
  String get amountPaidLabel => 'المبلغ المدفوع';

  @override
  String get markFullyPaidLabel => 'تعليم كمدفوع بالكامل';

  @override
  String get remainingLabel => 'المتبقي';

  @override
  String get invoiceTitle => 'الفاتورة';

  @override
  String get paymentStatusLabel => 'حالة الدفع';

  @override
  String get orderDetailsTitle => 'تفاصيل الطلب';

  @override
  String get paidAmountShortLabel => 'المدفوع';

  @override
  String get updateStatusLabel => 'تحديث الحالة';

  @override
  String get restaurantRecordPaymentAction => 'تسجيل الدفع';

  @override
  String get paymentRecordedMessage => 'تم تسجيل الدفع';

  @override
  String get enterValidAmountMessage => 'أدخل مبلغًا صالحًا';

  @override
  String get confirmAction => 'تأكيد';

  @override
  String get addInventoryItemTitle => 'إضافة عنصر للمخزون';

  @override
  String get applyAction => 'تطبيق';

  @override
  String get minStockLabel => 'الحد الأدنى للمخزون';

  @override
  String get noInventoryItemsMessage => 'لا توجد عناصر في المخزون';

  @override
  String get openingQuantityLabel => 'الكمية الافتتاحية';

  @override
  String get removeAction => 'إزالة';

  @override
  String get searchInventoryHint => 'البحث في المخزون...';

  @override
  String get supplierLabel => 'المورد';

  @override
  String get unitLabel => 'الوحدة';

  @override
  String get lowStockLabel => 'مخزون منخفض';

  @override
  String get enterNonZeroAmountMessage => 'أدخل مبلغًا غير صفري';

  @override
  String get manualAdjustmentLabel => 'تعديل يدوي';

  @override
  String get inventoryTitle => 'المخزون';

  @override
  String get saveRecipeAction => 'حفظ الوصفة';

  @override
  String get addAction => 'إضافة';

  @override
  String get ordersTitle => 'الطلبات';

  @override
  String get noActiveOrdersMessage => 'لا توجد طلبات نشطة حاليًا';

  @override
  String get moveToNextStageTooltip => 'الانتقال إلى المرحلة التالية';

  @override
  String get cancelOrderTooltip => 'إلغاء الطلب';

  @override
  String get takeawayLabel => 'طلب خارجي';

  @override
  String get newOrderTitle => 'طلب جديد';

  @override
  String get tableOptionalLabel =>
      'الطاولة (اختياري — طلب خارجي إذا تُرك فارغًا)';

  @override
  String get takeawayNoTableOption => 'طلب خارجي / بدون طاولة';

  @override
  String get noMenuItemsYetMessage =>
      'لا توجد أصناف في القائمة بعد — أضف بعضها من شاشة القائمة';

  @override
  String get addAtLeastOneItemMessage => 'أضف عنصرًا واحدًا على الأقل';

  @override
  String get orderCreatedMessage => 'تم إنشاء الطلب';

  @override
  String get createOrderAction => 'إنشاء الطلب';

  @override
  String get tablesTitle => 'الطاولات';

  @override
  String get addTableTitle => 'إضافة طاولة';

  @override
  String get tableNameFieldLabel => 'اسم / رقم الطاولة';

  @override
  String get seatsLabel => 'عدد المقاعد';

  @override
  String get noTablesYetMessage => 'لا توجد طاولات بعد';

  @override
  String get saveAction => 'حفظ';

  @override
  String get reservationsTitle => 'الحجوزات';

  @override
  String get newReservationTitle => 'حجز جديد';

  @override
  String get customerNameLabel => 'اسم العميل';

  @override
  String get partySizeLabel => 'عدد الأشخاص';

  @override
  String get noReservationsYetMessage => 'لا توجد حجوزات بعد';

  @override
  String get seatAction => 'إجلاس';

  @override
  String get menuTitle => 'القائمة';

  @override
  String get addMenuItemTitle => 'إضافة صنف';

  @override
  String get dishNameLabel => 'اسم الطبق';

  @override
  String get categoryOptionalLabel => 'الفئة (اختياري)';

  @override
  String get priceDzdLabel => 'السعر (دج)';

  @override
  String get enterValidPriceMessage => 'أدخل سعرًا صالحًا';

  @override
  String get recipeIngredientsTooltip => 'الوصفة (المكونات)';

  @override
  String get noShowLabel => 'لم يحضر';

  @override
  String get dateTimeLabel => 'التاريخ والوقت';

  @override
  String get guestsLabel => 'ضيوف';

  @override
  String adjustItemTitle(Object itemName) {
    return 'تعديل $itemName';
  }

  @override
  String adjustQuantityHint(Object unit) {
    return 'التغيير ($unit) — سالب للإزالة';
  }

  @override
  String get todayRevenueLabel => 'إيرادات اليوم';

  @override
  String get todayProfitLabel => 'ربح اليوم';

  @override
  String get outstandingPaymentsLabel => 'المدفوعات المستحقة';

  @override
  String get paymentStatusPaidLabel => 'مدفوع';

  @override
  String get paymentStatusPartialLabel => 'مدفوع جزئياً';

  @override
  String get paymentStatusUnpaidLabel => 'غير مدفوع';

  @override
  String get paymentStatusRefundedLabel => 'مسترجع';

  @override
  String get clinicRecordPaymentAction => 'تسجيل دفعة';

  @override
  String get cartEmpty => 'السلة فارغة — أضف منتجًا أعلاه';

  @override
  String cartLineLabel(Object name, Object qty) {
    return '$name × $qty';
  }

  @override
  String get discountDzdLabel => 'الخصم (دج)';

  @override
  String get confirmSaleButton => 'تأكيد البيع';

  @override
  String get searchProductDots => 'ابحث عن منتج...';

  @override
  String get outOfStockLabel => 'نفد من المخزون';

  @override
  String get storeDashboardTitle => 'لوحة تحكم المتجر';

  @override
  String get pharmacyDashboardTitle => 'لوحة تحكم الصيدلية';

  @override
  String get customerDebtLabel => 'ديون العملاء';

  @override
  String get stockValueLabel => 'قيمة المخزون';

  @override
  String get expiringSoonLabel => 'قرب انتهاء الصلاحية';

  @override
  String get inventoryValueLabel => 'قيمة المخزون';

  @override
  String get kpiSubtitleDzdToday => 'دج اليوم';

  @override
  String get kpiSubtitleNetToday => 'صافي، اليوم';

  @override
  String get transactionsLabel => 'المعاملات';

  @override
  String get stockAlertsTitle => 'تنبيهات المخزون';

  @override
  String get noStockAlertsMessage => 'لا توجد تنبيهات مخزون حاليًا';

  @override
  String get noStockOrExpiryAlertsMessage =>
      'لا توجد تنبيهات مخزون أو انتهاء صلاحية حاليًا';

  @override
  String get customerDebtTitle => 'ديون العملاء';

  @override
  String get noOutstandingDebtMessage => 'لا توجد ديون عملاء مستحقة';

  @override
  String get stockByCategoryTitle => 'المخزون حسب الفئة';

  @override
  String get noProductsYetMessage => 'لا توجد منتجات بعد';

  @override
  String get expirationDateLabel => 'تاريخ الصلاحية';

  @override
  String get selectDateHint => 'اختر التاريخ';

  @override
  String get clearDateAction => 'مسح';

  @override
  String get sizeLabel => 'المقاس';

  @override
  String get colorLabel => 'اللون';

  @override
  String get brandLabel => 'العلامة التجارية';

  @override
  String get editProductTitle => 'تعديل المنتج';

  @override
  String get editAction => 'تعديل';

  @override
  String get saveChangesAction => 'حفظ التغييرات';

  @override
  String get productUpdatedMessage => 'تم تحديث المنتج';

  @override
  String get goodDay => 'يوم سعيد';

  @override
  String get companyDashboardTitle => 'لوحة تحكم الشركة';

  @override
  String get openProjectsLabel => 'المشاريع المفتوحة';

  @override
  String get dzdThisMonthLabel => 'دج هذا الشهر';

  @override
  String get thisMonthLabel => 'هذا الشهر';

  @override
  String get netProfitLabel => 'الربح الصافي';

  @override
  String get salariesLabel => 'الرواتب';

  @override
  String todayRevenueProfit(Object revenue, Object profit) {
    return 'اليوم: $revenue إيرادات · $profit ربح';
  }

  @override
  String get projectsTitle => 'المشاريع';

  @override
  String get noOpenProjectsMessage => 'لا توجد مشاريع مفتوحة';

  @override
  String overdueCount(Object count) {
    return '$count متأخر';
  }

  @override
  String get unpaidInvoicesTitle => 'الفواتير غير المدفوعة';

  @override
  String get noUnpaidInvoicesMessage => 'لا توجد فواتير غير مدفوعة';

  @override
  String clientCreditBalancesMessage(Object amount) {
    return 'أرصدة ديون العملاء: $amount';
  }

  @override
  String get noProjectsYetMessage => 'لا توجد مشاريع بعد';

  @override
  String get dueDateBeforeStartDateError =>
      'تاريخ الاستحقاق لا يمكن أن يكون قبل تاريخ البداية';

  @override
  String get newProjectTitle => 'مشروع جديد';

  @override
  String get projectNameLabel => 'اسم المشروع';

  @override
  String get clientOptionalLabel => 'العميل (اختياري)';

  @override
  String get noClientOption => 'بدون عميل';

  @override
  String get budgetDzdOptionalLabel => 'الميزانية (دج، اختياري)';

  @override
  String get descriptionOptionalLabel => 'الوصف (اختياري)';

  @override
  String get startDateLabel => 'تاريخ البداية';

  @override
  String get dueDateLabel => 'تاريخ الاستحقاق';

  @override
  String get restaurantDashboardTitle => 'لوحة تحكم المطعم';

  @override
  String get tablesOccupiedLabel => 'الطاولات المشغولة';

  @override
  String get reservationsTodayLabel => 'حجوزات اليوم';

  @override
  String get todaysOrdersLabel => 'طلبات اليوم';

  @override
  String get activeOrdersLabel => 'الطلبات النشطة';

  @override
  String get inProgressLabel => 'قيد التنفيذ';

  @override
  String pendingCount(Object count) {
    return '$count في الانتظار';
  }

  @override
  String preparingCount(Object count) {
    return '$count قيد التحضير';
  }

  @override
  String readyCount(Object count) {
    return '$count جاهز';
  }

  @override
  String get clothingProductsTitle => 'منتجات الملابس';

  @override
  String get viewAllAction => 'عرض الكل';

  @override
  String get noClothingProductsMessage => 'لم يتم إضافة منتجات ملابس بعد';

  @override
  String expiresOnLabel(Object date) {
    return 'ينتهي في $date';
  }

  @override
  String deleteConfirmTitle(Object item) {
    return 'حذف $item';
  }

  @override
  String deleteConfirmMessage(Object item) {
    return 'هل أنت متأكد أنك تريد حذف ($item)؟';
  }

  @override
  String get serverSettingsTitle => 'إعدادات الخادم';

  @override
  String get serverBaseUrlLabel => 'رابط الخادم الرئيسي';

  @override
  String get testConnectionAction => 'اختبار الاتصال';

  @override
  String get editExpenseTitle => 'تعديل المصروف';

  @override
  String get updateExpenseAction => 'تحديث المصروف';

  @override
  String get editMenuItemTitle => 'تعديل الصنف';

  @override
  String recipeTitle(Object name) {
    return 'الوصفة — $name';
  }

  @override
  String quantityRequiredUnit(Object unit) {
    return 'الكمية المطلوبة ($unit)';
  }

  @override
  String enterValidQuantityFor(Object name) {
    return 'أدخل كمية صالحة لـ $name';
  }

  @override
  String get noPastOrdersFoundMessage => 'لم يتم العثور على طلبات سابقة';

  @override
  String get deleteMenuItemTitle => 'حذف الصنف';

  @override
  String get deleteSupplierTitle => 'حذف المورد';

  @override
  String get deleteCustomerTitle => 'حذف العميل';

  @override
  String get deleteEmployeeTitle => 'حذف الموظف';

  @override
  String get deleteExpenseTitle => 'حذف المصروف';

  @override
  String get deleteProductTitle => 'حذف المنتج';

  @override
  String get supplierFallback => 'المورد';

  @override
  String get customerFallback => 'العميل';

  @override
  String get expenseFallback => 'المصروف';

  @override
  String get personalProfileTitle => 'الملف الشخصي';

  @override
  String get saveProfile => 'حفظ الملف الشخصي';

  @override
  String get profileUpdatedSuccess => 'تم تحديث الملف الشخصي بنجاح';

  @override
  String errorUpdatingProfile(Object error) {
    return 'خطأ أثناء تحديث الملف الشخصي: $error';
  }

  @override
  String get businessInfoTitle => 'معلومات النشاط التجاري';

  @override
  String get updateBusinessInfo => 'تحديث معلومات النشاط';

  @override
  String get businessInfoUpdatedSuccess =>
      'تم تحديث معلومات النشاط التجاري بنجاح';

  @override
  String errorUpdatingBusiness(Object error) {
    return 'خطأ أثناء تحديث معلومات النشاط: $error';
  }

  @override
  String get changePasswordTitle => 'تغيير كلمة المرور';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get enterCurrentPassword => 'أدخل كلمة المرور الحالية';

  @override
  String get confirmNewPassword => 'تأكيد كلمة المرور الجديدة';

  @override
  String get confirmYourNewPassword => 'أكّد كلمة المرور الجديدة';

  @override
  String get updatePasswordAction => 'تحديث كلمة المرور';

  @override
  String get passwordChangedSuccess => 'تم تغيير كلمة المرور بنجاح';

  @override
  String errorChangingPassword(Object error) {
    return 'خطأ أثناء تغيير كلمة المرور: $error';
  }

  @override
  String get dangerZoneTitle => 'منطقة الخطر';

  @override
  String get deleteAccountPermanently => 'حذف الحساب نهائياً';

  @override
  String get deleteAccountWarning =>
      'سيؤدي حذف حسابك إلى حذف ملفك الشخصي وإعدادات نشاطك التجاري والمنتجات والمبيعات والفواتير نهائياً. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get enterPasswordToConfirm => 'أدخل كلمة المرور للتأكيد';

  @override
  String get deletePermanentlyAction => 'حذف نهائي';

  @override
  String accountDeletionFailed(Object error) {
    return 'فشل حذف الحساب: $error';
  }

  @override
  String failedToPickImage(Object error) {
    return 'فشل اختيار الصورة: $error';
  }

  @override
  String get businessPhoneLabel => 'هاتف العمل';

  @override
  String get businessAddressLabel => 'عنوان العمل';

  @override
  String get businessNameRequired => 'اسم النشاط التجاري مطلوب';

  @override
  String get reportRevenueLabel => 'الإيرادات';

  @override
  String get reportExpensesLabel => 'المصاريف';

  @override
  String get reportNetProfitLabel => 'صافي الأرباح';

  @override
  String get salesCountLabel => 'عدد المبيعات';

  @override
  String salesCountInPeriod(Object count) {
    return '$count عملية بيع في هذه الفترة';
  }

  @override
  String get topProductsTitle => 'المنتجات الأكثر مبيعاً';

  @override
  String unitsSoldLabel(Object count) {
    return 'تم بيع $count';
  }

  @override
  String get noActivityInPeriod => 'لا يوجد نشاط مسجل في هذه الفترة حتى الآن';

  @override
  String get aiActiveSnack => 'المساعد الذكي وماسح الفواتير نشطان';

  @override
  String get businessTypeRetail => 'متجر تجزئة عام';

  @override
  String get financialOverview => 'نظرة عامة مالية';

  @override
  String get revenueBreakdownTitle => 'تفاصيل الإيرادات';

  @override
  String get expensesBreakdownTitle => 'تفاصيل المصاريف';

  @override
  String get operatingExpensesLabel => 'مصاريف العمليات';

  @override
  String get employeeSalariesLabel => 'رواتب الموظفين';

  @override
  String get totalExpensesLabel => 'إجمالي المصاريف';

  @override
  String get profitCalculationTitle => 'حساب الأرباح';

  @override
  String get profitMarginLabel => 'هامش الربح';

  @override
  String get netLossLabel => 'خسارة صافية';

  @override
  String get activitySummaryTitle => 'ملخص النشاط';

  @override
  String get invoicesCountLabel => 'الفواتير';

  @override
  String get expensesCountLabel => 'المصاريف';

  @override
  String get employeesCountLabel => 'الموظفون';

  @override
  String get recentTransactionsTitle => 'المعاملات الأخيرة';

  @override
  String get noTransactionsInPeriod => 'لا توجد معاملات في هذه الفترة';

  @override
  String get coreSalesLabel => 'المبيعات المباشرة';

  @override
  String get creditPaymentsLabel => 'مدفوعات الديون';

  @override
  String get categoryBreakdownTitle => 'المصاريف حسب الفئة';

  @override
  String get employeeBreakdownTitle => 'الرواتب حسب الموظف';

  @override
  String get noEmployeesFound => 'لا يوجد موظفون مسجلون';

  @override
  String get noExpensesFound => 'لا توجد مصاريف مسجلة';

  @override
  String get profitFormulaExplanation =>
      'صافي الربح = إجمالي الإيرادات - إجمالي المصاريف';

  @override
  String get dateRangeLabel => 'الفترة الزمنية';

  @override
  String get scanStageUploading => 'جارٍ رفع صورة الفاتورة...';

  @override
  String get scanStageOcr => 'جارٍ التعرف الضوئي على النصوص (OCR)...';

  @override
  String get scanStageExtracting => 'جارٍ استخراج المنتجات والأسعار...';

  @override
  String get scanStageFinalizing => 'جارٍ إتمام استخراج بنود الفاتورة...';

  @override
  String get scanTimeoutMessage =>
      'انتهت مهلة مسح الفاتورة. يرجى المحاولة مرة أخرى أو فحص اتصال الذكاء الاصطناعي.';

  @override
  String get scanCancelledMessage => 'تم إلغاء مسح الفاتورة.';

  @override
  String get retryScanAction => 'إعادة المسح';

  @override
  String get aiServiceDisabledMessage =>
      'خدمات الذكاء الاصطناعي معطلة حالياً. يمكنك تفعيلها من الإعدادات.';

  @override
  String get aiServiceUnavailableMessage =>
      'خادم الذكاء الاصطناعي غير متاح. يرجى التحقق من الاتصال في الإعدادات.';

  @override
  String get scanFailedTitle => 'فشل المسح';

  @override
  String get scanSuccessTitle => 'تم مسح الفاتورة بنجاح';

  @override
  String get cancelScanAction => 'إلغاء المسح';

  @override
  String get aiStatusOnline => 'متصل';

  @override
  String get aiStatusDegraded => 'متدهور (نماذج مفقودة)';

  @override
  String get aiStatusOffline => 'غير متصل';

  @override
  String get aiStatusDisabled => 'معطل';

  @override
  String get aiEnabledLabel => 'تفعيل ميزات الذكاء الاصطناعي';

  @override
  String get aiEnabledDescription =>
      'استخدام الذكاء الاصطناعي المحلي لمسح الفواتير وOCR والتحليلات الذكية';

  @override
  String get aiServerUrlLabel => 'رابط خادم الذكاء الاصطناعي';

  @override
  String get aiServerUrlHint => 'مثال: http://10.0.2.2:11434/v1';

  @override
  String get aiOcrModelLabel => 'نموذج التعرف الضوئي (OCR)';

  @override
  String get aiVisionModelLabel => 'نموذج الرؤية (Vision)';

  @override
  String get aiChatModelLabel => 'نموذج المساعد الذكي / المحادثة';

  @override
  String get testAiConnectionAction => 'اختبار اتصال الذكاء الاصطناعي';

  @override
  String get aiConnectionSuccessMessage =>
      'تم الاتصال بخادم الذكاء الاصطناعي بنجاح';

  @override
  String aiConnectionFailedMessage(Object error) {
    return 'فشل الاتصال: $error';
  }

  @override
  String get availableModelsLabel => 'النماذج المتاحة على الخادم';

  @override
  String get missingModelsLabel => 'النماذج المفقودة';

  @override
  String get saveAiSettingsAction => 'حفظ إعدادات الذكاء الاصطناعي';

  @override
  String get aiSettingsSavedSuccess => 'تم حفظ إعدادات الذكاء الاصطناعي بنجاح';

  @override
  String get couldNotLoadSalesTrend => 'تعذر تحميل مؤشر المبيعات';

  @override
  String get askAboutYourBusiness => 'اسأل عن نشاطك التجاري';

  @override
  String get aiAnswersComputedLive =>
      'الإجابات محسوبة مباشرة من بياناتك الحقيقية';

  @override
  String get changeStatusTitle => 'تغيير الحالة';

  @override
  String get deleteProductTooltip => 'حذف المنتج';

  @override
  String get projectStatusPlanned => 'مخطط';

  @override
  String get projectStatusInProgress => 'قيد التنفيذ';

  @override
  String get projectStatusOnHold => 'معلّق';

  @override
  String get projectStatusCompleted => 'مكتمل';

  @override
  String get projectStatusCancelled => 'ملغى';

  @override
  String get projectStatusOverdue => 'متأخر';

  @override
  String get globalNetProfitTitle => 'صافي الربح الإجمالي';

  @override
  String get allRevenueLabel => 'إجمالي الإيرادات';

  @override
  String get allExpensesLabel => 'إجمالي المصروفات';

  @override
  String get globalBalanceLabel => 'الرصيد الكلي';

  @override
  String get selectDate => 'اختر التاريخ';

  @override
  String get selectMonth => 'اختر الشهر';

  @override
  String get selectYear => 'اختر السنة';

  @override
  String get salaryPeriodLabel => 'فترة الراتب';

  @override
  String get paymentDateLabel => 'تاريخ الدفع';

  @override
  String get paySalary => 'دفع الراتب';

  @override
  String get recordSalaryPayment => 'تسجيل دفع راتب';

  @override
  String get duplicateSalaryWarningTitle => 'تم دفع الراتب مسبقاً';

  @override
  String get duplicateSalaryWarningMessage =>
      'تم تسجيل دفع راتب لهذا الموظف عن هذه الفترة مسبقاً. هل أنت متأكد من تسجيل دفعة أخرى؟';

  @override
  String get monthlyBreakdownTitle => 'التفصيل الشهري';

  @override
  String get noTransactionsForPeriod => 'لا توجد معاملات مسجلة لهذه الفترة';

  @override
  String get salaryExpenseLabel => 'مصاريف الرواتب';

  @override
  String get otherExpensesLabel => 'المصاريف الأخرى';

  @override
  String get chooseEmployee => 'اختر الموظف';

  @override
  String get salaryPaidSuccess => 'تم تسجيل دفع الراتب بنجاح';

  @override
  String get dailyReportTitle => 'التقرير اليومي';

  @override
  String get monthlyReportTitle => 'التقرير الشهري';

  @override
  String get yearlyReportTitle => 'التقرير السنوي';
}
