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
  String get businessTypeGrocery => 'متجر بقالة';

  @override
  String get businessTypeGroceryDesc => 'تواريخ الصلاحية، الموردون';

  @override
  String get businessTypePharmacy => 'صيدلية';

  @override
  String get businessTypePharmacyDesc => 'المخزون، تنبيهات الصلاحية';

  @override
  String get businessTypeClinic => 'عيادة / طبيب';

  @override
  String get businessTypeClinicDesc => 'المرضى، المواعيد';

  @override
  String get businessTypeRestaurant => 'مطعم';

  @override
  String get businessTypeRestaurantDesc => 'قائمة الطعام، المكوّنات';

  @override
  String get businessTypeCompany => 'شركة';

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
  String get baseSalaryLabel => 'الراتب الأساسي (دج)';

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
  String get businessProfileSubtitle => 'التعديل من الإعدادات غير متاح بعد';

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
}
