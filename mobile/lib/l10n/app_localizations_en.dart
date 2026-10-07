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
  String get businessTypeGrocery => 'Market / Store';

  @override
  String get businessTypeGroceryDesc =>
      'Supermarket, mini market, grocery, convenience store';

  @override
  String get businessTypePharmacy => 'Pharmacy';

  @override
  String get businessTypePharmacyDesc => 'Stock, expiration alerts';

  @override
  String get businessTypeClinic => 'Clinic / Medical';

  @override
  String get businessTypeClinicDesc =>
      'Patients, appointments — medical & dental';

  @override
  String get businessTypeRestaurant => 'Restaurant / Café';

  @override
  String get businessTypeRestaurantDesc =>
      'Menu, orders, tables — restaurants & cafés';

  @override
  String get businessTypeCompany => 'Enterprise / Company';

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
  String get baseSalaryLabel => 'Base Salary';

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
  String get businessProfileSubtitle => 'Manage personal and business details';

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
  String get salePriceFieldLabel => 'Sale price';

  @override
  String get salePriceRequired =>
      'Please enter a valid sale price for all products';

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
  String get noItemsDetected =>
      'No items were detected in that photo — try again with better lighting.';

  @override
  String get expensePeriodTypeLabel => 'Period type';

  @override
  String get periodOneTime => 'One-time';

  @override
  String get periodCustom => 'Custom';

  @override
  String get periodStartLabel => 'From';

  @override
  String get periodEndLabel => 'To';

  @override
  String expenseCoversDays(Object days) {
    return 'Covers $days day(s)';
  }

  @override
  String get selectPeriodEndDate =>
      'Please pick an end date for this custom period';

  @override
  String get selectCustomerFirst => 'Please select a customer first';

  @override
  String get noCustomersYet => 'No customers yet — add one first';

  @override
  String get amountExceedsTotal => 'Amount to pay cannot exceed the total';

  @override
  String get creditSaleTitle => 'New Credit Sale';

  @override
  String get selectCustomerHint => 'Select a customer';

  @override
  String get amountToPayNowLabel => 'Amount to Pay Now (DZD)';

  @override
  String get remainingCreditLabel => 'Remaining Credit';

  @override
  String get confirmCreditSaleButton => 'Confirm Credit Sale';

  @override
  String get creditSaleRecorded => 'Credit sale recorded';

  @override
  String get creditPageTitle => 'Credit';

  @override
  String get newCreditSaleAction => 'New Credit Sale';

  @override
  String get customersWithCreditTitle => 'Customers with outstanding credit';

  @override
  String get noOutstandingCredit => 'No customer currently owes anything';

  @override
  String get totalCreditLabel => 'Total Credit';

  @override
  String get totalPaidLabel => 'Paid';

  @override
  String get noOutstandingBalanceForCustomer =>
      'This customer has no outstanding balance';

  @override
  String get recordPaymentTitle => 'Record Payment';

  @override
  String currentBalanceHelper(Object balance) {
    return 'Current balance: $balance DZD';
  }

  @override
  String get paymentRecorded => 'Payment recorded';

  @override
  String get noTransactionsYet => 'No transactions yet';

  @override
  String get creditPurchaseLabel => 'Credit Purchase';

  @override
  String get paymentLabel => 'Payment';

  @override
  String balanceAfterLabel(Object balance) {
    return 'Balance after: $balance DZD';
  }

  @override
  String get clinicDashboardTitle => 'Clinic Dashboard';

  @override
  String get patientsTodayLabel => 'Patients Today';

  @override
  String get appointmentsTodayLabel => 'Appointments Today';

  @override
  String get waitingLabel => 'Waiting';

  @override
  String get completedTodayLabel => 'Completed Today';

  @override
  String get noShowTodayLabel => 'No-Shows Today';

  @override
  String get newPatientsTodayLabel => 'New Patients Today';

  @override
  String get doctorsLabel => 'Doctors';

  @override
  String get clinicQueueTitle => 'Waiting Room';

  @override
  String get callNextPatientButton => 'Call Next Patient';

  @override
  String nextPatientLabel(Object name) {
    return 'Next Patient: $name';
  }

  @override
  String get noOneWaitingMessage => 'No one is waiting right now';

  @override
  String get completeConsultationButton => 'Complete Consultation';

  @override
  String get clinicPatientsTitle => 'Patients';

  @override
  String get addPatientTitle => 'Add Patient';

  @override
  String get fullNameLabel => 'Full name';

  @override
  String get genderLabel => 'Gender';

  @override
  String get dateOfBirthLabel => 'Date of birth';

  @override
  String get savePatient => 'Save Patient';

  @override
  String get patientProfileTitle => 'Patient Profile';

  @override
  String get visitHistoryTitle => 'Visit History';

  @override
  String get noVisitsYetMessage => 'No visits recorded yet';

  @override
  String get diagnosisLabel => 'Diagnosis';

  @override
  String get treatmentLabel => 'Treatment';

  @override
  String get prescriptionLabel => 'Prescription';

  @override
  String get followUpDateLabel => 'Follow-up date';

  @override
  String get addToQueueAction => 'Add to Queue';

  @override
  String get selectPatientTitle => 'Select Patient';

  @override
  String get searchPatientsHint => 'Search patients...';

  @override
  String get noPatientsFoundMessage => 'No patients found';

  @override
  String get delete => 'Delete';

  @override
  String get documentsTitle => 'Medical Documents';

  @override
  String get addDocumentAction => 'Add Document';

  @override
  String get documentNameLabel => 'Document name';

  @override
  String get documentTypeLabel => 'Document type';

  @override
  String get fileUrlLabel => 'File URL';

  @override
  String get noDocumentsYetMessage => 'No documents yet';

  @override
  String get confirmDeleteDocumentMessage => 'Delete this document?';

  @override
  String get documentDeletedMessage => 'Document deleted';

  @override
  String get documentAddedMessage => 'Document added';

  @override
  String get prescriptionsTitle => 'Prescriptions';

  @override
  String get newPrescriptionAction => 'New Prescription';

  @override
  String get noPrescriptionsYetMessage => 'No prescriptions yet';

  @override
  String get medicationNameLabel => 'Medication name';

  @override
  String get dosageLabel => 'Dosage';

  @override
  String get frequencyLabel => 'Frequency';

  @override
  String get durationLabel => 'Duration';

  @override
  String get instructionsLabel => 'Instructions';

  @override
  String get addMedicationAction => 'Add Medication';

  @override
  String get savePrescriptionAction => 'Save Prescription';

  @override
  String get prescriptionSavedMessage => 'Prescription saved';

  @override
  String get prescriptionNumberLabel => 'Prescription No.';

  @override
  String get medicationRequiredMessage => 'At least one medication is required';

  @override
  String get patientAddedMessage => 'Patient added';

  @override
  String get queueEmptyMessage => 'The waiting room is empty';

  @override
  String get consultationPriceLabel => 'Consultation Price';

  @override
  String get amountPaidLabel => 'Amount Paid';

  @override
  String get markFullyPaidLabel => 'Mark as fully paid';

  @override
  String get remainingLabel => 'Remaining';

  @override
  String get invoiceTitle => 'Invoice';

  @override
  String get paymentStatusLabel => 'Payment status';

  @override
  String get orderDetailsTitle => 'Order Details';

  @override
  String get paidAmountShortLabel => 'Paid';

  @override
  String get updateStatusLabel => 'Update Status';

  @override
  String get restaurantRecordPaymentAction => 'Record Payment';

  @override
  String get paymentRecordedMessage => 'Payment recorded';

  @override
  String get enterValidAmountMessage => 'Enter a valid amount';

  @override
  String get confirmAction => 'Confirm';

  @override
  String get addInventoryItemTitle => 'Add Inventory Item';

  @override
  String get applyAction => 'Apply';

  @override
  String get minStockLabel => 'Min. stock';

  @override
  String get noInventoryItemsMessage => 'No inventory items';

  @override
  String get openingQuantityLabel => 'Opening qty';

  @override
  String get removeAction => 'Remove';

  @override
  String get searchInventoryHint => 'Search inventory...';

  @override
  String get supplierLabel => 'Supplier';

  @override
  String get unitLabel => 'Unit';

  @override
  String get lowStockLabel => 'Low stock';

  @override
  String get enterNonZeroAmountMessage => 'Enter a non-zero amount';

  @override
  String get manualAdjustmentLabel => 'Manual adjustment';

  @override
  String get inventoryTitle => 'Inventory';

  @override
  String get saveRecipeAction => 'Save Recipe';

  @override
  String get addAction => 'Add';

  @override
  String get ordersTitle => 'Orders';

  @override
  String get noActiveOrdersMessage => 'No active orders right now';

  @override
  String get moveToNextStageTooltip => 'Move to next stage';

  @override
  String get cancelOrderTooltip => 'Cancel order';

  @override
  String get takeawayLabel => 'Takeaway';

  @override
  String get newOrderTitle => 'New Order';

  @override
  String get tableOptionalLabel => 'Table (optional — takeaway if empty)';

  @override
  String get takeawayNoTableOption => 'Takeaway / no table';

  @override
  String get noMenuItemsYetMessage =>
      'No menu items yet — add some from the Menu screen';

  @override
  String get addAtLeastOneItemMessage => 'Add at least one item';

  @override
  String get orderCreatedMessage => 'Order created';

  @override
  String get createOrderAction => 'Create Order';

  @override
  String get tablesTitle => 'Tables';

  @override
  String get addTableTitle => 'Add Table';

  @override
  String get tableNameFieldLabel => 'Table name / number';

  @override
  String get seatsLabel => 'Seats';

  @override
  String get noTablesYetMessage => 'No tables yet';

  @override
  String get saveAction => 'Save';

  @override
  String get reservationsTitle => 'Reservations';

  @override
  String get newReservationTitle => 'New Reservation';

  @override
  String get customerNameLabel => 'Customer name';

  @override
  String get partySizeLabel => 'Party size';

  @override
  String get noReservationsYetMessage => 'No reservations yet';

  @override
  String get seatAction => 'Seat';

  @override
  String get menuTitle => 'Menu';

  @override
  String get addMenuItemTitle => 'Add Menu Item';

  @override
  String get dishNameLabel => 'Dish name';

  @override
  String get categoryOptionalLabel => 'Category (optional)';

  @override
  String get priceDzdLabel => 'Price (DZD)';

  @override
  String get enterValidPriceMessage => 'Enter a valid price';

  @override
  String get recipeIngredientsTooltip => 'Recipe (ingredients)';

  @override
  String get noShowLabel => 'No-show';

  @override
  String get dateTimeLabel => 'Date & time';

  @override
  String get guestsLabel => 'guests';

  @override
  String adjustItemTitle(Object itemName) {
    return 'Adjust $itemName';
  }

  @override
  String adjustQuantityHint(Object unit) {
    return 'Change ($unit) — negative to remove';
  }

  @override
  String get todayRevenueLabel => 'Today\'s Revenue';

  @override
  String get todayProfitLabel => 'Today\'s Profit';

  @override
  String get outstandingPaymentsLabel => 'Outstanding Payments';

  @override
  String get paymentStatusPaidLabel => 'Paid';

  @override
  String get paymentStatusPartialLabel => 'Partially Paid';

  @override
  String get paymentStatusUnpaidLabel => 'Unpaid';

  @override
  String get paymentStatusRefundedLabel => 'Refunded';

  @override
  String get clinicRecordPaymentAction => 'Record Payment';

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

  @override
  String get storeDashboardTitle => 'Store Dashboard';

  @override
  String get pharmacyDashboardTitle => 'Pharmacy Dashboard';

  @override
  String get customerDebtLabel => 'Customer debt';

  @override
  String get stockValueLabel => 'Stock value';

  @override
  String get expiringSoonLabel => 'Expiring soon';

  @override
  String get inventoryValueLabel => 'Inventory value';

  @override
  String get kpiSubtitleDzdToday => 'DZD today';

  @override
  String get kpiSubtitleNetToday => 'Net, today';

  @override
  String get transactionsLabel => 'Transactions';

  @override
  String get stockAlertsTitle => 'Stock Alerts';

  @override
  String get noStockAlertsMessage => 'No stock alerts right now';

  @override
  String get noStockOrExpiryAlertsMessage =>
      'No stock or expiry alerts right now';

  @override
  String get customerDebtTitle => 'Customer Debt';

  @override
  String get noOutstandingDebtMessage => 'No outstanding customer debt';

  @override
  String get stockByCategoryTitle => 'Stock by Category';

  @override
  String get noProductsYetMessage => 'No products yet';

  @override
  String get expirationDateLabel => 'Expiration date';

  @override
  String get selectDateHint => 'Select date';

  @override
  String get clearDateAction => 'Clear';

  @override
  String get sizeLabel => 'Size';

  @override
  String get colorLabel => 'Color';

  @override
  String get brandLabel => 'Brand';

  @override
  String get editProductTitle => 'Edit Product';

  @override
  String get editAction => 'Edit';

  @override
  String get saveChangesAction => 'Save Changes';

  @override
  String get productUpdatedMessage => 'Product updated';

  @override
  String get goodDay => 'Good day';

  @override
  String get companyDashboardTitle => 'Company Dashboard';

  @override
  String get openProjectsLabel => 'Open projects';

  @override
  String get dzdThisMonthLabel => 'DZD this month';

  @override
  String get thisMonthLabel => 'This month';

  @override
  String get netProfitLabel => 'Net profit';

  @override
  String get salariesLabel => 'Salaries';

  @override
  String todayRevenueProfit(Object revenue, Object profit) {
    return 'Today: $revenue revenue · $profit profit';
  }

  @override
  String get projectsTitle => 'Projects';

  @override
  String get noOpenProjectsMessage => 'No open projects';

  @override
  String overdueCount(Object count) {
    return '$count overdue';
  }

  @override
  String get unpaidInvoicesTitle => 'Unpaid Invoices';

  @override
  String get noUnpaidInvoicesMessage => 'No unpaid invoices';

  @override
  String clientCreditBalancesMessage(Object amount) {
    return 'Client credit balances: $amount';
  }

  @override
  String get noProjectsYetMessage => 'No projects yet';

  @override
  String get dueDateBeforeStartDateError =>
      'Due date cannot be before the start date';

  @override
  String get newProjectTitle => 'New Project';

  @override
  String get projectNameLabel => 'Project name';

  @override
  String get clientOptionalLabel => 'Client (optional)';

  @override
  String get noClientOption => 'No client';

  @override
  String get budgetDzdOptionalLabel => 'Budget (DZD, optional)';

  @override
  String get descriptionOptionalLabel => 'Description (optional)';

  @override
  String get startDateLabel => 'Start date';

  @override
  String get dueDateLabel => 'Due date';

  @override
  String get restaurantDashboardTitle => 'Restaurant Dashboard';

  @override
  String get tablesOccupiedLabel => 'Tables occupied';

  @override
  String get reservationsTodayLabel => 'Reservations today';

  @override
  String get todaysOrdersLabel => 'Today\'s Orders';

  @override
  String get activeOrdersLabel => 'Active Orders';

  @override
  String get inProgressLabel => 'In progress';

  @override
  String pendingCount(Object count) {
    return '$count pending';
  }

  @override
  String preparingCount(Object count) {
    return '$count preparing';
  }

  @override
  String readyCount(Object count) {
    return '$count ready';
  }

  @override
  String get clothingProductsTitle => 'Clothing Products';

  @override
  String get viewAllAction => 'View All';

  @override
  String get noClothingProductsMessage => 'No clothing products added yet';

  @override
  String expiresOnLabel(Object date) {
    return 'expires $date';
  }

  @override
  String deleteConfirmTitle(Object item) {
    return 'Delete $item';
  }

  @override
  String deleteConfirmMessage(Object item) {
    return 'Are you sure you want to delete this $item?';
  }

  @override
  String get serverSettingsTitle => 'Server Settings';

  @override
  String get serverBaseUrlLabel => 'Server Base URL';

  @override
  String get testConnectionAction => 'Test Connection';

  @override
  String get editExpenseTitle => 'Edit Expense';

  @override
  String get updateExpenseAction => 'Update Expense';

  @override
  String get editMenuItemTitle => 'Edit Menu Item';

  @override
  String recipeTitle(Object name) {
    return 'Recipe — $name';
  }

  @override
  String quantityRequiredUnit(Object unit) {
    return 'Quantity required ($unit)';
  }

  @override
  String enterValidQuantityFor(Object name) {
    return 'Enter a valid quantity for $name';
  }

  @override
  String get noPastOrdersFoundMessage => 'No past orders found';

  @override
  String get deleteMenuItemTitle => 'Delete Menu Item';

  @override
  String get deleteSupplierTitle => 'Delete Supplier';

  @override
  String get deleteCustomerTitle => 'Delete Customer';

  @override
  String get deleteEmployeeTitle => 'Delete Employee';

  @override
  String get deleteExpenseTitle => 'Delete Expense';

  @override
  String get deleteProductTitle => 'Delete Product';

  @override
  String get supplierFallback => 'Supplier';

  @override
  String get customerFallback => 'Customer';

  @override
  String get expenseFallback => 'Expense';

  @override
  String get personalProfileTitle => 'Personal Profile';

  @override
  String get saveProfile => 'Save Profile';

  @override
  String get profileUpdatedSuccess => 'Profile updated successfully';

  @override
  String errorUpdatingProfile(Object error) {
    return 'Error updating profile: $error';
  }

  @override
  String get businessInfoTitle => 'Business Information';

  @override
  String get updateBusinessInfo => 'Update Business Info';

  @override
  String get businessInfoUpdatedSuccess =>
      'Business information updated successfully';

  @override
  String errorUpdatingBusiness(Object error) {
    return 'Error updating business info: $error';
  }

  @override
  String get changePasswordTitle => 'Change Password';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get enterCurrentPassword => 'Enter current password';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get confirmYourNewPassword => 'Confirm your new password';

  @override
  String get updatePasswordAction => 'Update Password';

  @override
  String get passwordChangedSuccess => 'Password changed successfully';

  @override
  String errorChangingPassword(Object error) {
    return 'Error changing password: $error';
  }

  @override
  String get dangerZoneTitle => 'Danger Zone';

  @override
  String get deleteAccountPermanently => 'Delete Account Permanently';

  @override
  String get deleteAccountWarning =>
      'Deleting your account will permanently delete your profile, business settings, products, sales, and invoices. This action cannot be undone.';

  @override
  String get enterPasswordToConfirm => 'Enter your password to confirm';

  @override
  String get deletePermanentlyAction => 'Delete Permanently';

  @override
  String accountDeletionFailed(Object error) {
    return 'Account deletion failed: $error';
  }

  @override
  String failedToPickImage(Object error) {
    return 'Failed to pick image: $error';
  }

  @override
  String get businessPhoneLabel => 'Business Phone';

  @override
  String get businessAddressLabel => 'Business Address';

  @override
  String get businessNameRequired => 'Business name is required';

  @override
  String get reportRevenueLabel => 'Revenue';

  @override
  String get reportExpensesLabel => 'Expenses';

  @override
  String get reportNetProfitLabel => 'Net Profit';

  @override
  String get salesCountLabel => 'Sales count';

  @override
  String salesCountInPeriod(Object count) {
    return '$count sale(s) in this period';
  }

  @override
  String get topProductsTitle => 'Top Products';

  @override
  String unitsSoldLabel(Object count) {
    return '$count sold';
  }

  @override
  String get noActivityInPeriod => 'No activity recorded for this period yet';

  @override
  String get aiActiveSnack => 'AI Assistant & OCR Scanner Active';

  @override
  String get businessTypeRetail => 'General Retail Store';

  @override
  String get financialOverview => 'Financial Overview';

  @override
  String get revenueBreakdownTitle => 'Revenue Breakdown';

  @override
  String get expensesBreakdownTitle => 'Expense Breakdown';

  @override
  String get operatingExpensesLabel => 'Business Expenses';

  @override
  String get employeeSalariesLabel => 'Employee Salaries';

  @override
  String get totalExpensesLabel => 'Total Expenses';

  @override
  String get profitCalculationTitle => 'Profit Calculation';

  @override
  String get profitMarginLabel => 'Profit Margin';

  @override
  String get netLossLabel => 'Net Loss';

  @override
  String get activitySummaryTitle => 'Activity Summary';

  @override
  String get invoicesCountLabel => 'Invoices';

  @override
  String get expensesCountLabel => 'Expenses';

  @override
  String get employeesCountLabel => 'Employees';

  @override
  String get recentTransactionsTitle => 'Recent Transactions';

  @override
  String get noTransactionsInPeriod => 'No transactions in this period';

  @override
  String get coreSalesLabel => 'Direct Sales';

  @override
  String get creditPaymentsLabel => 'Credit Payments';

  @override
  String get categoryBreakdownTitle => 'Expenses by Category';

  @override
  String get employeeBreakdownTitle => 'Salaries by Employee';

  @override
  String get noEmployeesFound => 'No employees registered';

  @override
  String get noExpensesFound => 'No business expenses recorded';

  @override
  String get profitFormulaExplanation =>
      'Net Profit = Total Revenue - Total Expenses';

  @override
  String get dateRangeLabel => 'Date Range';

  @override
  String get scanStageUploading => 'Uploading invoice image...';

  @override
  String get scanStageOcr => 'Running OCR text recognition...';

  @override
  String get scanStageExtracting => 'Extracting products and prices...';

  @override
  String get scanStageFinalizing => 'Finalizing extracted invoice items...';

  @override
  String get scanTimeoutMessage =>
      'Invoice scanning timed out. Please try again or verify AI connection.';

  @override
  String get scanCancelledMessage => 'Invoice scan was cancelled.';

  @override
  String get retryScanAction => 'Retry Scan';

  @override
  String get aiServiceDisabledMessage =>
      'AI services are currently disabled. Please enable them in Settings.';

  @override
  String get aiServiceUnavailableMessage =>
      'AI server is unreachable. Check your AI server connection in Settings.';

  @override
  String get scanFailedTitle => 'Scan Failed';

  @override
  String get scanSuccessTitle => 'Invoice Scanned Successfully';

  @override
  String get cancelScanAction => 'Cancel Scan';

  @override
  String get aiStatusOnline => 'Online';

  @override
  String get aiStatusDegraded => 'Degraded (Missing Models)';

  @override
  String get aiStatusOffline => 'Offline';

  @override
  String get aiStatusDisabled => 'Disabled';

  @override
  String get aiEnabledLabel => 'Enable AI Features';

  @override
  String get aiEnabledDescription =>
      'Use local AI for invoice scanning, OCR, and smart business insights';

  @override
  String get aiServerUrlLabel => 'AI Server URL';

  @override
  String get aiServerUrlHint => 'e.g. http://10.0.2.2:11434/v1';

  @override
  String get aiOcrModelLabel => 'OCR Model';

  @override
  String get aiVisionModelLabel => 'Vision Model';

  @override
  String get aiChatModelLabel => 'Assistant / Chat Model';

  @override
  String get testAiConnectionAction => 'Test AI Connection';

  @override
  String get aiConnectionSuccessMessage =>
      'Successfully connected to AI server';

  @override
  String aiConnectionFailedMessage(Object error) {
    return 'Connection failed: $error';
  }

  @override
  String get availableModelsLabel => 'Available Models on Server';

  @override
  String get missingModelsLabel => 'Missing Models';

  @override
  String get saveAiSettingsAction => 'Save AI Settings';

  @override
  String get aiSettingsSavedSuccess => 'AI settings saved successfully';

  @override
  String get couldNotLoadSalesTrend => 'Could not load sales trend';

  @override
  String get askAboutYourBusiness => 'Ask about your business';

  @override
  String get aiAnswersComputedLive =>
      'Answers are computed live from your real data';

  @override
  String get changeStatusTitle => 'Change Status';

  @override
  String get deleteProductTooltip => 'Delete Product';

  @override
  String get projectStatusPlanned => 'Planned';

  @override
  String get projectStatusInProgress => 'In progress';

  @override
  String get projectStatusOnHold => 'On hold';

  @override
  String get projectStatusCompleted => 'Completed';

  @override
  String get projectStatusCancelled => 'Cancelled';

  @override
  String get projectStatusOverdue => 'Overdue';

  @override
  String get globalNetProfitTitle => 'Global Net Profit';

  @override
  String get allRevenueLabel => 'All Revenue';

  @override
  String get allExpensesLabel => 'All Expenses';

  @override
  String get globalBalanceLabel => 'All-Time Balance';

  @override
  String get selectDate => 'Select Date';

  @override
  String get selectMonth => 'Select Month';

  @override
  String get selectYear => 'Select Year';

  @override
  String get salaryPeriodLabel => 'Salary Period';

  @override
  String get paymentDateLabel => 'Payment Date';

  @override
  String get paySalary => 'Pay Salary';

  @override
  String get recordSalaryPayment => 'Record Salary Payment';

  @override
  String get duplicateSalaryWarningTitle => 'Salary Already Paid';

  @override
  String get duplicateSalaryWarningMessage =>
      'A salary payment for this employee for this period already exists. Are you sure you want to record another payment?';

  @override
  String get monthlyBreakdownTitle => 'Monthly Breakdown';

  @override
  String get noTransactionsForPeriod =>
      'No transactions recorded for this period';

  @override
  String get salaryExpenseLabel => 'Salary Expenses';

  @override
  String get otherExpensesLabel => 'Other Expenses';

  @override
  String get chooseEmployee => 'Choose Employee';

  @override
  String get salaryPaidSuccess => 'Salary payment recorded successfully';

  @override
  String get dailyReportTitle => 'Daily Report';

  @override
  String get monthlyReportTitle => 'Monthly Report';

  @override
  String get yearlyReportTitle => 'Yearly Report';

  @override
  String get connectionOnline => 'Connected';

  @override
  String get connectionOffline => 'Offline — Data saved on device';

  @override
  String get connectionServerUnavailable =>
      'Server unavailable — Working offline';

  @override
  String syncingPending(Object count) {
    return 'Syncing $count pending operations...';
  }

  @override
  String get syncSuccess => 'All operations synchronized';

  @override
  String get syncFailed => 'Some operations failed to sync';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get pendingOperations => 'Pending Operations';

  @override
  String get syncedOperations => 'Synced Operations';

  @override
  String get failedOperations => 'Failed Operations';

  @override
  String get syncDetails => 'Sync Details';

  @override
  String lastSynced(Object time) {
    return 'Last synced: $time';
  }

  @override
  String get noPendingOperations => 'No pending operations to sync';

  @override
  String get firstTimeAuthInternetRequired =>
      'Internet connection is required for first-time account authentication.';

  @override
  String get firstTimeRegisterInternetRequired =>
      'Internet connection is required to create a new account.';

  @override
  String activeClients(Object count) {
    return 'Active Carts ($count)';
  }

  @override
  String get newClientAction => '+ New Customer';

  @override
  String get holdCartAction => 'Hold Cart';

  @override
  String get resumeCartAction => 'Resume';

  @override
  String get clearCartAction => 'Clear Cart';

  @override
  String get cartOnHoldStatus => 'On Hold';

  @override
  String cartItemCount(Object count) {
    return '$count items';
  }

  @override
  String get openCartsTitle => 'Open Carts';

  @override
  String get newCartAction => '+ New Cart';

  @override
  String get noOpenCarts => 'No open carts — tap + to start';

  @override
  String cartLabel(Object index) {
    return 'Cart $index';
  }

  @override
  String cartProductCount(Object count) {
    return '$count products';
  }

  @override
  String get deleteCartTooltip => 'Delete cart';

  @override
  String get deleteCartTitle => 'Delete Cart';

  @override
  String deleteCartConfirm(Object name) {
    return 'Delete cart for $name? This cannot be undone.';
  }

  @override
  String orderNumberLabel(Object number) {
    return 'ORDER #$number';
  }

  @override
  String get dineInOption => 'Dine-in';

  @override
  String get takeawayOption => 'Takeaway';

  @override
  String get deliveryOption => 'Delivery';

  @override
  String get paymentStatusPaidBadge => 'PAID';

  @override
  String get paymentStatusUnpaidBadge => 'UNPAID';

  @override
  String get paymentStatusPartiallyPaidBadge => 'PARTIALLY PAID';

  @override
  String get orderNotReadyMessage => 'Order is not ready yet.';

  @override
  String get paymentRequiredMessage =>
      'Payment is required before completing the order.';

  @override
  String get completeOrderAction => 'Complete Order';

  @override
  String get payNowAction => 'Pay Now';

  @override
  String get payFullAmountAction => 'Pay Full Amount';

  @override
  String get partialPaymentAction => 'Partial Payment';

  @override
  String get remainingAmountLabel => 'Remaining';

  @override
  String get paymentCompletedTitle => 'Payment';

  @override
  String get tableStatusAvailable => 'AVAILABLE';

  @override
  String get tableStatusOccupied => 'OCCUPIED';

  @override
  String get tableStatusOrderReady => 'ORDER READY';

  @override
  String get tableStatusPaymentPending => 'PAYMENT PENDING';

  @override
  String get tableStatusCompleted => 'COMPLETED';

  @override
  String get switchOrderAction => 'Switch Order';

  @override
  String elapsedMinutes(Object minutes) {
    return '$minutes min ago';
  }

  @override
  String get elapsedJustNow => 'Just now';

  @override
  String get preparationStatusLabel => 'Preparation';

  @override
  String get orderTypeLabel => 'Order Type';

  @override
  String get anonymousWalkInCustomer => 'Walk-in';

  @override
  String get dashboardPagesTitle => 'Pages';

  @override
  String get allPagesTitle => 'All Pages';

  @override
  String get allPagesSubtitle => 'All business tools and modules';

  @override
  String get extraPagesTitle => 'Extra Pages';

  @override
  String get salesPosTitle => 'Sales POS';

  @override
  String get cashPaymentMethod => 'Cash';

  @override
  String get cardPaymentMethod => 'Card';

  @override
  String get editItemTooltip => 'Edit item';

  @override
  String get previousDayTooltip => 'Previous Day';

  @override
  String get nextDayTooltip => 'Next Day';

  @override
  String get previousMonthTooltip => 'Previous Month';

  @override
  String get nextMonthTooltip => 'Next Month';

  @override
  String get previousYearTooltip => 'Previous Year';

  @override
  String get nextYearTooltip => 'Next Year';

  @override
  String customerHasUnpaidDebt(Object amount) {
    return 'Cannot delete customer with unpaid debt ($amount DZD)';
  }

  @override
  String customerDeletedSuccess(Object name) {
    return 'Customer \"$name\" deleted';
  }

  @override
  String employeeDeletedSuccess(Object name) {
    return 'Employee \"$name\" deleted';
  }

  @override
  String supplierDeletedSuccess(Object name) {
    return 'Supplier \"$name\" deleted';
  }

  @override
  String get invalidBarcodeChecksum =>
      'Invalid barcode checksum (corrupt or unreadable)';

  @override
  String get invalidBarcodeFormat => 'Invalid barcode format';

  @override
  String get configureServerUrlHint => 'Configure backend API address:';

  @override
  String get appTagline => 'AI-Powered Business Management';

  @override
  String get clientPhoneNumberLabel => 'Client phone number';

  @override
  String get clientPhoneRequired => 'Phone number is required for delivery';

  @override
  String get invalidPhoneNumber => 'Invalid phone number format';

  @override
  String get deliveryAddressLabel => 'Delivery address';

  @override
  String get deliveryAddressHint => 'Street, building, floor, apartment...';

  @override
  String get deliveryAddressRequired => 'Delivery address is required';

  @override
  String get noTableSelected => 'No table (optional)';

  @override
  String get selectRestaurantTable => 'Restaurant table (optional)';

  @override
  String assignedTableLabel(Object name) {
    return 'Table: $name';
  }

  @override
  String get editAppointmentTitle => 'Edit Appointment';

  @override
  String get updateAppointmentAction => 'Update Appointment';

  @override
  String get editReservationTitle => 'Edit Reservation';

  @override
  String get updateReservationAction => 'Update Reservation';

  @override
  String get callClientTooltip => 'Call client';

  @override
  String get copyPhoneTooltip => 'Copy phone number';

  @override
  String get phoneCopiedMessage => 'Phone number copied to clipboard';

  @override
  String get selectExistingCustomerHint => 'Or select registered customer';

  @override
  String get editOrderTitle => 'Edit Order';

  @override
  String get updateOrderAction => 'Update Order';

  @override
  String get orderUpdatedMessage => 'Order updated successfully';

  @override
  String get moreSectionOperations => 'Operations & Commerce';

  @override
  String get moreSectionSpecialized => 'Specialized Activity';

  @override
  String get moreSectionIntelligence => 'AI & Intelligence';

  @override
  String get moreSectionSystem => 'System & Account';
}
