// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Modiri AI';

  @override
  String get onboardingTitle1 => 'Manage Your Business';

  @override
  String get onboardingDesc1 =>
      'Track sales, stock and profit in one place, from your phone.';

  @override
  String get onboardingTitle2 => 'Track Your Inventory';

  @override
  String get onboardingDesc2 =>
      'Never run out of stock — get alerts before products sell out.';

  @override
  String get onboardingTitle3 => 'Work Smarter with AI';

  @override
  String get onboardingDesc3 =>
      'Scan supplier invoices and ask your AI assistant about your business.';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get Started';

  @override
  String get loginTitle => 'Welcome Back';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get login => 'Login';

  @override
  String get noAccount => 'Don\'t have an account? Register';

  @override
  String get registerTitle => 'Create Account';

  @override
  String get fullName => 'Full name';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get createAccount => 'Create Account';

  @override
  String get haveAccount => 'Already have an account? Login';

  @override
  String get selectBusinessType => 'Select Business Type';

  @override
  String stepOf(Object current, Object total) {
    return 'Step $current of $total';
  }

  @override
  String get chooseBusinessTypeHint =>
      'Choose the option that best matches your business';

  @override
  String get businessTypeClothing => 'Clothing Store';

  @override
  String get businessTypeClothingDesc => 'Sizes, colors, barcode';

  @override
  String get businessTypeGrocery => 'Grocery Store';

  @override
  String get businessTypeGroceryDesc => 'Expiration, suppliers';

  @override
  String get businessTypePharmacy => 'Pharmacy';

  @override
  String get businessTypePharmacyDesc => 'Stock, expiration alerts';

  @override
  String get businessTypeClinic => 'Clinic / Doctor';

  @override
  String get businessTypeClinicDesc => 'Patients, appointments';

  @override
  String get businessTypeRestaurant => 'Restaurant';

  @override
  String get businessTypeRestaurantDesc => 'Menu, ingredients';

  @override
  String get businessTypeCompany => 'Company';

  @override
  String get businessTypeCompanyDesc => 'Employees, invoices';

  @override
  String get businessTypeWorkshop => 'Workshop / Artisan';

  @override
  String get businessTypeWorkshopDesc => 'Orders, services';

  @override
  String get continueLabel => 'Continue';

  @override
  String get businessSetupTitle => 'Business Setup';

  @override
  String get businessName => 'Business name';

  @override
  String get businessNameHint => 'e.g. Amine Grocery';

  @override
  String get businessTypeLabel => 'Business type';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get address => 'Address';

  @override
  String get addressHint => 'City, street';

  @override
  String get currency => 'Currency';

  @override
  String get finishSetup => 'Finish Setup';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navSales => 'Sales';

  @override
  String get navInventory => 'Inventory';

  @override
  String get navMore => 'More';

  @override
  String get moreInvoices => 'Invoices';

  @override
  String get moreExpenses => 'Expenses';

  @override
  String get moreEmployees => 'Employees';

  @override
  String get moreAppointments => 'Appointments';

  @override
  String get moreReports => 'Reports';

  @override
  String get moreAiAssistant => 'AI Assistant';

  @override
  String get moreNotifications => 'Notifications';

  @override
  String get moreSettings => 'Settings';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get dashboardRevenue => 'Revenue';

  @override
  String get dashboardProfit => 'Profit';

  @override
  String get dashboardLowStock => 'Low Stock';

  @override
  String dashboardTodayCurrency(Object currency) {
    return 'Today · $currency';
  }

  @override
  String get dashboardToday => 'Today';

  @override
  String get dashboardNeedsReview => 'Needs review';

  @override
  String get dashboardAllGood => 'All good';

  @override
  String get salesTrend => 'Sales trend';

  @override
  String get rangeWeek => 'Week';

  @override
  String get rangeMonth => 'Month';

  @override
  String get rangeYear => 'Year';

  @override
  String get newSale => 'New Sale';

  @override
  String get scanInvoice => 'Scan Invoice';

  @override
  String lowStockMessage(Object count) {
    return '$count product(s) are running low';
  }

  @override
  String get noSalesInPeriod => 'No sales recorded in this period yet';

  @override
  String get verifyAccountTitle => 'Verify Your Account';

  @override
  String verifyAccountSubtitle(Object email) {
    return 'We sent a 6-digit code to $email';
  }

  @override
  String get verifyCodeLabel => 'Verification code';

  @override
  String get verifyEnterFullCode => 'Enter the 6-digit code';

  @override
  String get verifyResendCode => 'Resend code';

  @override
  String verifyResendIn(Object seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get verifyCodeResent => 'Code sent';

  @override
  String get verifyAccountButton => 'Verify';

  @override
  String get backToLogin => 'Back to login';

  @override
  String get networkError =>
      'Could not reach the server — check your connection';

  @override
  String get forgotPasswordTitle => 'Forgot Password';

  @override
  String get forgotPasswordSubtitle =>
      'Enter your email and we\'ll send you a reset code';

  @override
  String get sendResetCode => 'Send reset code';

  @override
  String resetPasswordSubtitle(Object email) {
    return 'Enter the code sent to $email and choose a new password';
  }

  @override
  String get newPassword => 'New password';

  @override
  String get resetPasswordButton => 'Reset Password';

  @override
  String get useAnotherEmail => 'Use a different email';

  @override
  String get passwordResetSuccess => 'Password reset — please log in';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get emailInvalid => 'Enter a valid email';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get passwordTooShort => 'Minimum 6 characters';

  @override
  String get nameRequired => 'Enter your full name';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get loginSubtitle => 'Log in to your business dashboard';

  @override
  String get yourNameHint => 'Your name';

  @override
  String get moreTitle => 'More';

  @override
  String get moreCustomers => 'Customers';

  @override
  String get moreSuppliers => 'Suppliers';

  @override
  String get moreAiScanner => 'AI Invoice Scanner';

  @override
  String get moreAiInsights => 'AI Insights';

  @override
  String errorPrefix(Object error) {
    return 'Error: $error';
  }

  @override
  String get retry => 'Retry';

  @override
  String get salesEmptyState => 'No sales yet — tap + to record one';

  @override
  String saleNumberFallback(Object id) {
    return 'Sale #$id';
  }

  @override
  String get walkInCustomer => 'Walk-in';

  @override
  String saleRowSubtitle(Object customer, Object count) {
    return '$customer · $count item(s)';
  }

  @override
  String get requiredField => 'Required';

  @override
  String get enterValidAmount => 'Enter a valid amount';

  @override
  String get employeesTitle => 'Employees';

  @override
  String get addEmployee => 'Add Employee';

  @override
  String get saveEmployee => 'Save Employee';

  @override
  String get positionLabel => 'Position';

  @override
  String get baseSalaryLabel => 'Base salary (DZD)';

  @override
  String get staffDefault => 'Staff';

  @override
  String get employeeFallback => 'Employee';

  @override
  String get attendancePresent => 'Present';

  @override
  String get attendanceAbsent => 'Absent';

  @override
  String get attendanceLate => 'Late';

  @override
  String get salaryThisMonth => 'Salary this month';

  @override
  String baseSalaryValue(Object amount) {
    return 'Base: $amount';
  }

  @override
  String get markPresent => 'Mark Present';

  @override
  String get markAbsent => 'Mark Absent';

  @override
  String get invoicesTitle => 'Invoices';

  @override
  String get noInvoicesYet => 'No invoices yet';

  @override
  String get statusUnpaid => 'Unpaid';

  @override
  String get statusPaid => 'Paid';

  @override
  String get invoiceFallback => 'Invoice';

  @override
  String get billTo => 'Bill To';

  @override
  String get itemsLabel => 'Items';

  @override
  String get totalLabel => 'Total';

  @override
  String lineItemLabel(Object name, Object qty) {
    return '$name × $qty';
  }

  @override
  String get pdfExportNotImplemented =>
      'PDF export: backend endpoint exists but is not implemented yet';

  @override
  String get shareViaWhatsapp => 'Share via WhatsApp';

  @override
  String balanceDue(Object amount) {
    return '$amount DZD due';
  }

  @override
  String get noBalanceDue => '0 DZD due';

  @override
  String get addCustomer => 'Add Customer';

  @override
  String get saveCustomer => 'Save Customer';

  @override
  String get nameLabel => 'Name';

  @override
  String get phoneLabel => 'Phone';

  @override
  String productsSuppliedCount(Object count) {
    return '$count products supplied';
  }

  @override
  String get addSupplier => 'Add Supplier';

  @override
  String get saveSupplier => 'Save Supplier';

  @override
  String get expensesTitle => 'Expenses';

  @override
  String get thisMonthTotal => 'This month\'s total';

  @override
  String get noExpensesYet => 'No expenses recorded yet';

  @override
  String get addExpense => 'Add Expense';

  @override
  String get saveExpense => 'Save Expense';

  @override
  String get categoryLabel => 'Category';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get optionalNoteHint => 'Optional note';

  @override
  String get amountDzdLabel => 'Amount (DZD)';

  @override
  String get noNotifications => 'No notifications — everything looks good';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get businessProfileTitle => 'Business Profile';

  @override
  String get businessProfileSubtitle => 'Edit-from-Settings UI not wired yet';

  @override
  String get businessProfileSnack =>
      'Business profile is set during onboarding — an edit screen is a follow-up';

  @override
  String get currencyTitle => 'Currency';

  @override
  String get themeTitle => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get languageTitle => 'Language';

  @override
  String get aiSettingsTitle => 'AI Settings';

  @override
  String get aiSettingsSubtitle => 'Rate limits, usage — Phase 6';

  @override
  String get logoutTitle => 'Logout';

  @override
  String get logoutConfirm => 'Are you sure you want to log out?';

  @override
  String get cancel => 'Cancel';

  @override
  String get setupSaveFailedTitle => 'Setup could not be saved';

  @override
  String get ok => 'OK';

  @override
  String productsTitleCount(Object count) {
    return 'Products · $count';
  }

  @override
  String get productsTitle => 'Products';

  @override
  String get searchProductsHint => 'Search products...';

  @override
  String get noProductsFound => 'No products found';

  @override
  String get qtyOutOfStock => 'Qty: 0 — Out of stock';

  @override
  String qtyLowStock(Object qty) {
    return 'Qty: $qty — Low stock';
  }

  @override
  String qtyOnly(Object qty) {
    return 'Qty: $qty';
  }

  @override
  String get productNotFound => 'Product not found';

  @override
  String get inStockLabel => 'In Stock';

  @override
  String get marginLabel => 'Margin';

  @override
  String get pricingLabel => 'Pricing';

  @override
  String purchasePriceValue(Object amount) {
    return 'Purchase: $amount DZD';
  }

  @override
  String sellingPriceValue(Object amount) {
    return 'Selling: $amount DZD';
  }

  @override
  String profitPerUnitValue(Object amount) {
    return 'Profit/unit: $amount DZD';
  }

  @override
  String get categoryLabelTitle => 'Category';

  @override
  String get enterValidNumber => 'Enter a valid number';

  @override
  String get mustBeNonNegative => 'Must be ≥ 0';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get addProductTitle => 'Add Product';

  @override
  String get productNameLabel => 'Product name';

  @override
  String get productNameHint => 'e.g. Whole Milk 1L';

  @override
  String get categoryHint => 'Dairy';

  @override
  String get purchasePriceLabel => 'Purchase price (DZD)';

  @override
  String get sellingPriceLabel => 'Selling price (DZD)';

  @override
  String get sellingBelowPurchaseWarning =>
      '⚠ Selling price is below purchase price';

  @override
  String get quantityLabel => 'Quantity';

  @override
  String get enterValidInteger => 'Enter a valid integer ≥ 0';

  @override
  String get saveProduct => 'Save Product';

  @override
  String get appointmentsTitle => 'Appointments';

  @override
  String get noAppointmentsScheduled => 'No appointments scheduled';

  @override
  String get markCompleted => 'Mark Completed';

  @override
  String get cancelAppointment => 'Cancel';

  @override
  String appointmentTimeName(Object time, Object name) {
    return '$time — $name';
  }

  @override
  String get newAppointmentTitle => 'New Appointment';

  @override
  String get patientCustomerLabel => 'Patient / Customer';

  @override
  String timeLabel(Object time) {
    return 'Time: $time';
  }

  @override
  String get notesLabel => 'Notes';

  @override
  String get optionalHint => 'Optional';

  @override
  String get saveAppointment => 'Save Appointment';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get periodDaily => 'Daily';

  @override
  String get periodWeekly => 'Weekly';

  @override
  String get periodMonthly => 'Monthly';

  @override
  String get periodYearly => 'Yearly';

  @override
  String get exportAsPdf => 'Export as PDF';

  @override
  String get exportAsExcel => 'Export as Excel';

  @override
  String get exportComingSoon => 'PDF/Excel export lands in a future batch';

  @override
  String get aiInsightsTitle => 'AI Insights';

  @override
  String get notEnoughDataForInsights =>
      'Not enough data yet to generate insights';

  @override
  String get scanInvoiceTitle => 'Scan Invoice';

  @override
  String get pointCameraAtInvoice => 'Point camera at invoice';

  @override
  String get keepInvoiceFlatWellLit => 'Keep the invoice flat and well lit';

  @override
  String get cameraButton => 'Camera';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get tryDemoInvoice => '▶ Try Demo Invoice';

  @override
  String get analyzingInvoice => 'Analyzing invoice...';

  @override
  String get readingTextDetecting =>
      'Reading text, detecting products and quantities';

  @override
  String get detectedItemsTitle => 'Detected Items';

  @override
  String qtyValue(Object qty) {
    return 'Qty: $qty';
  }

  @override
  String get reviewAndEdit => 'Review & Edit';

  @override
  String get reviewItemsTitle => 'Review Items';

  @override
  String get productNameFieldLabel => 'Product name';

  @override
  String get quantityFieldLabel => 'Quantity';

  @override
  String get purchasePriceFieldLabel => 'Purchase price';

  @override
  String get confirmAddToInventory => 'Confirm & Add to Inventory';

  @override
  String productsAddedToInventory(Object count) {
    return '$count product(s) added to inventory';
  }

  @override
  String get noProductsLoadedYet =>
      'No products loaded yet — check your connection and try again';

  @override
  String onlyNInStock(Object qty, Object name) {
    return 'Only $qty in stock for $name';
  }

  @override
  String outOfStockFor(Object name) {
    return '$name is out of stock';
  }

  @override
  String get addAtLeastOneProduct => 'Add at least one product to the cart';

  @override
  String get saleRecordedSuccessfully => 'Sale recorded successfully';

  @override
  String couldNotCompleteSale(Object error) {
    return 'Could not complete sale: $error';
  }

  @override
  String get newSaleTitle => 'New Sale';

  @override
  String get searchProductOrScan => 'Search product or scan barcode';

  @override
  String get scanInvoiceChooserTitle => 'Which invoice do you want to scan?';

  @override
  String get scanSalesInvoiceOption => 'Sales Invoice';

  @override
  String get scanSalesInvoiceSubtitle =>
      'Record a sale from a customer receipt';

  @override
  String get scanStockInvoiceOption => 'Stock Invoice';

  @override
  String get scanStockInvoiceSubtitle => 'Add purchased items to inventory';

  @override
  String get scanBarcodeTooltip => 'Scan barcode';

  @override
  String get barcodeScannerTitle => 'Scan Barcode';

  @override
  String get barcodeScannerHint => 'Align the barcode within the frame';

  @override
  String get enterCodeManually => 'Enter code manually';

  @override
  String get manualBarcodeEntryTitle => 'Enter Barcode';

  @override
  String barcodeNotFoundMessage(Object code) {
    return 'No product matches barcode $code';
  }

  @override
  String get addAsNewProductAction => 'Add as new product';

  @override
  String scannedProductAddedToCart(Object name) {
    return '$name added to the cart';
  }

  @override
  String get matchProductLabel => 'Matched product';

  @override
  String get selectProductHint => 'Select a product';

  @override
  String get salesInvoiceReviewTitle => 'Review Sale Items';

  @override
  String get confirmRecordSale => 'Confirm & Record Sale';

  @override
  String get saleRecordedFromScan => 'Sale recorded from scanned invoice';

  @override
  String get pleaseMatchAllItems =>
      'Match every item to a product before continuing';

  @override
  String get cameraPermissionRequired =>
      'Camera permission is required to scan';

  @override
  String get noMatchFound => 'No match found — select manually';

  @override
  String get unitPriceLabel => 'Unit price';

  @override
  String get removeItemLabel => 'Remove';

  @override
  String get barcodeFieldLabel => 'Barcode (optional)';

  @override
  String get barcodeFieldHint => 'Scan or type manually';

  @override
  String get cartEmpty => 'Cart is empty — add a product above';

  @override
  String cartLineLabel(Object name, Object qty) {
    return '$name × $qty';
  }

  @override
  String get discountDzdLabel => 'Discount (DZD)';

  @override
  String get confirmSaleButton => 'Confirm Sale';

  @override
  String get searchProductDots => 'Search product...';

  @override
  String get outOfStockLabel => 'Out of stock';
}
