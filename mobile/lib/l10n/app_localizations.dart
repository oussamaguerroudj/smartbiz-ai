import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Modiri AI'**
  String get appName;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Manage Your Business'**
  String get onboardingTitle1;

  /// No description provided for @onboardingDesc1.
  ///
  /// In en, this message translates to:
  /// **'Track sales, stock and profit in one place, from your phone.'**
  String get onboardingDesc1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Track Your Inventory'**
  String get onboardingTitle2;

  /// No description provided for @onboardingDesc2.
  ///
  /// In en, this message translates to:
  /// **'Never run out of stock — get alerts before products sell out.'**
  String get onboardingDesc2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Work Smarter with AI'**
  String get onboardingTitle3;

  /// No description provided for @onboardingDesc3.
  ///
  /// In en, this message translates to:
  /// **'Scan supplier invoices and ask your AI assistant about your business.'**
  String get onboardingDesc3;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get loginTitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Register'**
  String get noAccount;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registerTitle;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Login'**
  String get haveAccount;

  /// No description provided for @selectBusinessType.
  ///
  /// In en, this message translates to:
  /// **'Select Business Type'**
  String get selectBusinessType;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String stepOf(Object current, Object total);

  /// No description provided for @chooseBusinessTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the option that best matches your business'**
  String get chooseBusinessTypeHint;

  /// No description provided for @businessTypeClothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing Store'**
  String get businessTypeClothing;

  /// No description provided for @businessTypeClothingDesc.
  ///
  /// In en, this message translates to:
  /// **'Sizes, colors, barcode'**
  String get businessTypeClothingDesc;

  /// No description provided for @businessTypeGrocery.
  ///
  /// In en, this message translates to:
  /// **'Grocery Store'**
  String get businessTypeGrocery;

  /// No description provided for @businessTypeGroceryDesc.
  ///
  /// In en, this message translates to:
  /// **'Expiration, suppliers'**
  String get businessTypeGroceryDesc;

  /// No description provided for @businessTypePharmacy.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get businessTypePharmacy;

  /// No description provided for @businessTypePharmacyDesc.
  ///
  /// In en, this message translates to:
  /// **'Stock, expiration alerts'**
  String get businessTypePharmacyDesc;

  /// No description provided for @businessTypeClinic.
  ///
  /// In en, this message translates to:
  /// **'Clinic / Doctor'**
  String get businessTypeClinic;

  /// No description provided for @businessTypeClinicDesc.
  ///
  /// In en, this message translates to:
  /// **'Patients, appointments'**
  String get businessTypeClinicDesc;

  /// No description provided for @businessTypeRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get businessTypeRestaurant;

  /// No description provided for @businessTypeRestaurantDesc.
  ///
  /// In en, this message translates to:
  /// **'Menu, ingredients'**
  String get businessTypeRestaurantDesc;

  /// No description provided for @businessTypeCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get businessTypeCompany;

  /// No description provided for @businessTypeCompanyDesc.
  ///
  /// In en, this message translates to:
  /// **'Employees, invoices'**
  String get businessTypeCompanyDesc;

  /// No description provided for @businessTypeWorkshop.
  ///
  /// In en, this message translates to:
  /// **'Workshop / Artisan'**
  String get businessTypeWorkshop;

  /// No description provided for @businessTypeWorkshopDesc.
  ///
  /// In en, this message translates to:
  /// **'Orders, services'**
  String get businessTypeWorkshopDesc;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @businessSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Business Setup'**
  String get businessSetupTitle;

  /// No description provided for @businessName.
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get businessName;

  /// No description provided for @businessNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Amine Grocery'**
  String get businessNameHint;

  /// No description provided for @businessTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Business type'**
  String get businessTypeLabel;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @addressHint.
  ///
  /// In en, this message translates to:
  /// **'City, street'**
  String get addressHint;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @finishSetup.
  ///
  /// In en, this message translates to:
  /// **'Finish Setup'**
  String get finishSetup;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get navSales;

  /// No description provided for @navInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get navInventory;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @moreInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get moreInvoices;

  /// No description provided for @moreExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get moreExpenses;

  /// No description provided for @moreEmployees.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get moreEmployees;

  /// No description provided for @moreAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get moreAppointments;

  /// No description provided for @moreReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get moreReports;

  /// No description provided for @moreAiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get moreAiAssistant;

  /// No description provided for @moreNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get moreNotifications;

  /// No description provided for @moreSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get moreSettings;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @dashboardRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get dashboardRevenue;

  /// No description provided for @dashboardProfit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get dashboardProfit;

  /// No description provided for @dashboardLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get dashboardLowStock;

  /// No description provided for @dashboardTodayCurrency.
  ///
  /// In en, this message translates to:
  /// **'Today · {currency}'**
  String dashboardTodayCurrency(Object currency);

  /// No description provided for @dashboardToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dashboardToday;

  /// No description provided for @dashboardNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get dashboardNeedsReview;

  /// No description provided for @dashboardAllGood.
  ///
  /// In en, this message translates to:
  /// **'All good'**
  String get dashboardAllGood;

  /// No description provided for @salesTrend.
  ///
  /// In en, this message translates to:
  /// **'Sales trend'**
  String get salesTrend;

  /// No description provided for @rangeWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get rangeWeek;

  /// No description provided for @rangeMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get rangeMonth;

  /// No description provided for @rangeYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get rangeYear;

  /// No description provided for @newSale.
  ///
  /// In en, this message translates to:
  /// **'New Sale'**
  String get newSale;

  /// No description provided for @scanInvoice.
  ///
  /// In en, this message translates to:
  /// **'Scan Invoice'**
  String get scanInvoice;

  /// No description provided for @lowStockMessage.
  ///
  /// In en, this message translates to:
  /// **'{count} product(s) are running low'**
  String lowStockMessage(Object count);

  /// No description provided for @noSalesInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No sales recorded in this period yet'**
  String get noSalesInPeriod;

  /// No description provided for @verifyAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Account'**
  String get verifyAccountTitle;

  /// No description provided for @verifyAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {email}'**
  String verifyAccountSubtitle(Object email);

  /// No description provided for @verifyCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get verifyCodeLabel;

  /// No description provided for @verifyEnterFullCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get verifyEnterFullCode;

  /// No description provided for @verifyResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get verifyResendCode;

  /// No description provided for @verifyResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String verifyResendIn(Object seconds);

  /// No description provided for @verifyCodeResent.
  ///
  /// In en, this message translates to:
  /// **'Code sent'**
  String get verifyCodeResent;

  /// No description provided for @verifyAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyAccountButton;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get backToLogin;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server — check your connection'**
  String get networkError;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a reset code'**
  String get forgotPasswordSubtitle;

  /// No description provided for @sendResetCode.
  ///
  /// In en, this message translates to:
  /// **'Send reset code'**
  String get sendResetCode;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to {email} and choose a new password'**
  String resetPasswordSubtitle(Object email);

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @resetPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordButton;

  /// No description provided for @useAnotherEmail.
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get useAnotherEmail;

  /// No description provided for @passwordResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset — please log in'**
  String get passwordResetSuccess;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get emailInvalid;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Minimum 6 characters'**
  String get passwordTooShort;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get nameRequired;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to your business dashboard'**
  String get loginSubtitle;

  /// No description provided for @yourNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourNameHint;

  /// No description provided for @moreTitle.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreTitle;

  /// No description provided for @moreCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get moreCustomers;

  /// No description provided for @moreSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get moreSuppliers;

  /// No description provided for @moreAiScanner.
  ///
  /// In en, this message translates to:
  /// **'AI Invoice Scanner'**
  String get moreAiScanner;

  /// No description provided for @moreAiInsights.
  ///
  /// In en, this message translates to:
  /// **'AI Insights'**
  String get moreAiInsights;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorPrefix(Object error);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @salesEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No sales yet — tap + to record one'**
  String get salesEmptyState;

  /// No description provided for @saleNumberFallback.
  ///
  /// In en, this message translates to:
  /// **'Sale #{id}'**
  String saleNumberFallback(Object id);

  /// No description provided for @walkInCustomer.
  ///
  /// In en, this message translates to:
  /// **'Walk-in'**
  String get walkInCustomer;

  /// No description provided for @saleRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{customer} · {count} item(s)'**
  String saleRowSubtitle(Object customer, Object count);

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// No description provided for @enterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get enterValidAmount;

  /// No description provided for @employeesTitle.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get employeesTitle;

  /// No description provided for @addEmployee.
  ///
  /// In en, this message translates to:
  /// **'Add Employee'**
  String get addEmployee;

  /// No description provided for @saveEmployee.
  ///
  /// In en, this message translates to:
  /// **'Save Employee'**
  String get saveEmployee;

  /// No description provided for @positionLabel.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get positionLabel;

  /// No description provided for @baseSalaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Base salary (DZD)'**
  String get baseSalaryLabel;

  /// No description provided for @staffDefault.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get staffDefault;

  /// No description provided for @employeeFallback.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get employeeFallback;

  /// No description provided for @attendancePresent.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get attendancePresent;

  /// No description provided for @attendanceAbsent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get attendanceAbsent;

  /// No description provided for @attendanceLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get attendanceLate;

  /// No description provided for @salaryThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Salary this month'**
  String get salaryThisMonth;

  /// No description provided for @baseSalaryValue.
  ///
  /// In en, this message translates to:
  /// **'Base: {amount}'**
  String baseSalaryValue(Object amount);

  /// No description provided for @markPresent.
  ///
  /// In en, this message translates to:
  /// **'Mark Present'**
  String get markPresent;

  /// No description provided for @markAbsent.
  ///
  /// In en, this message translates to:
  /// **'Mark Absent'**
  String get markAbsent;

  /// No description provided for @invoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoicesTitle;

  /// No description provided for @noInvoicesYet.
  ///
  /// In en, this message translates to:
  /// **'No invoices yet'**
  String get noInvoicesYet;

  /// No description provided for @statusUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get statusUnpaid;

  /// No description provided for @statusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get statusPaid;

  /// No description provided for @invoiceFallback.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoiceFallback;

  /// No description provided for @billTo.
  ///
  /// In en, this message translates to:
  /// **'Bill To'**
  String get billTo;

  /// No description provided for @itemsLabel.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get itemsLabel;

  /// No description provided for @totalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// No description provided for @lineItemLabel.
  ///
  /// In en, this message translates to:
  /// **'{name} × {qty}'**
  String lineItemLabel(Object name, Object qty);

  /// No description provided for @pdfExportNotImplemented.
  ///
  /// In en, this message translates to:
  /// **'PDF export: backend endpoint exists but is not implemented yet'**
  String get pdfExportNotImplemented;

  /// No description provided for @shareViaWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Share via WhatsApp'**
  String get shareViaWhatsapp;

  /// No description provided for @balanceDue.
  ///
  /// In en, this message translates to:
  /// **'{amount} DZD due'**
  String balanceDue(Object amount);

  /// No description provided for @noBalanceDue.
  ///
  /// In en, this message translates to:
  /// **'0 DZD due'**
  String get noBalanceDue;

  /// No description provided for @addCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add Customer'**
  String get addCustomer;

  /// No description provided for @saveCustomer.
  ///
  /// In en, this message translates to:
  /// **'Save Customer'**
  String get saveCustomer;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @productsSuppliedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} products supplied'**
  String productsSuppliedCount(Object count);

  /// No description provided for @addSupplier.
  ///
  /// In en, this message translates to:
  /// **'Add Supplier'**
  String get addSupplier;

  /// No description provided for @saveSupplier.
  ///
  /// In en, this message translates to:
  /// **'Save Supplier'**
  String get saveSupplier;

  /// No description provided for @expensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesTitle;

  /// No description provided for @thisMonthTotal.
  ///
  /// In en, this message translates to:
  /// **'This month\'s total'**
  String get thisMonthTotal;

  /// No description provided for @noExpensesYet.
  ///
  /// In en, this message translates to:
  /// **'No expenses recorded yet'**
  String get noExpensesYet;

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add Expense'**
  String get addExpense;

  /// No description provided for @saveExpense.
  ///
  /// In en, this message translates to:
  /// **'Save Expense'**
  String get saveExpense;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @optionalNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Optional note'**
  String get optionalNoteHint;

  /// No description provided for @amountDzdLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount (DZD)'**
  String get amountDzdLabel;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications — everything looks good'**
  String get noNotifications;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @businessProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Business Profile'**
  String get businessProfileTitle;

  /// No description provided for @businessProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Edit-from-Settings UI not wired yet'**
  String get businessProfileSubtitle;

  /// No description provided for @businessProfileSnack.
  ///
  /// In en, this message translates to:
  /// **'Business profile is set during onboarding — an edit screen is a follow-up'**
  String get businessProfileSnack;

  /// No description provided for @currencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currencyTitle;

  /// No description provided for @themeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeTitle;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @aiSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Settings'**
  String get aiSettingsTitle;

  /// No description provided for @aiSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rate limits, usage — Phase 6'**
  String get aiSettingsSubtitle;

  /// No description provided for @logoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutTitle;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logoutConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @setupSaveFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Setup could not be saved'**
  String get setupSaveFailedTitle;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @productsTitleCount.
  ///
  /// In en, this message translates to:
  /// **'Products · {count}'**
  String productsTitleCount(Object count);

  /// No description provided for @productsTitle.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get productsTitle;

  /// No description provided for @searchProductsHint.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get searchProductsHint;

  /// No description provided for @noProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get noProductsFound;

  /// No description provided for @qtyOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Qty: 0 — Out of stock'**
  String get qtyOutOfStock;

  /// No description provided for @qtyLowStock.
  ///
  /// In en, this message translates to:
  /// **'Qty: {qty} — Low stock'**
  String qtyLowStock(Object qty);

  /// No description provided for @qtyOnly.
  ///
  /// In en, this message translates to:
  /// **'Qty: {qty}'**
  String qtyOnly(Object qty);

  /// No description provided for @productNotFound.
  ///
  /// In en, this message translates to:
  /// **'Product not found'**
  String get productNotFound;

  /// No description provided for @inStockLabel.
  ///
  /// In en, this message translates to:
  /// **'In Stock'**
  String get inStockLabel;

  /// No description provided for @marginLabel.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get marginLabel;

  /// No description provided for @pricingLabel.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get pricingLabel;

  /// No description provided for @purchasePriceValue.
  ///
  /// In en, this message translates to:
  /// **'Purchase: {amount} DZD'**
  String purchasePriceValue(Object amount);

  /// No description provided for @sellingPriceValue.
  ///
  /// In en, this message translates to:
  /// **'Selling: {amount} DZD'**
  String sellingPriceValue(Object amount);

  /// No description provided for @profitPerUnitValue.
  ///
  /// In en, this message translates to:
  /// **'Profit/unit: {amount} DZD'**
  String profitPerUnitValue(Object amount);

  /// No description provided for @categoryLabelTitle.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabelTitle;

  /// No description provided for @enterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get enterValidNumber;

  /// No description provided for @mustBeNonNegative.
  ///
  /// In en, this message translates to:
  /// **'Must be ≥ 0'**
  String get mustBeNonNegative;

  /// No description provided for @uncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// No description provided for @addProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProductTitle;

  /// No description provided for @productNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Product name'**
  String get productNameLabel;

  /// No description provided for @productNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Whole Milk 1L'**
  String get productNameHint;

  /// No description provided for @categoryHint.
  ///
  /// In en, this message translates to:
  /// **'Dairy'**
  String get categoryHint;

  /// No description provided for @purchasePriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Purchase price (DZD)'**
  String get purchasePriceLabel;

  /// No description provided for @sellingPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Selling price (DZD)'**
  String get sellingPriceLabel;

  /// No description provided for @sellingBelowPurchaseWarning.
  ///
  /// In en, this message translates to:
  /// **'⚠ Selling price is below purchase price'**
  String get sellingBelowPurchaseWarning;

  /// No description provided for @quantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantityLabel;

  /// No description provided for @enterValidInteger.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid integer ≥ 0'**
  String get enterValidInteger;

  /// No description provided for @saveProduct.
  ///
  /// In en, this message translates to:
  /// **'Save Product'**
  String get saveProduct;

  /// No description provided for @appointmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointmentsTitle;

  /// No description provided for @noAppointmentsScheduled.
  ///
  /// In en, this message translates to:
  /// **'No appointments scheduled'**
  String get noAppointmentsScheduled;

  /// No description provided for @markCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark Completed'**
  String get markCompleted;

  /// No description provided for @cancelAppointment.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAppointment;

  /// No description provided for @appointmentTimeName.
  ///
  /// In en, this message translates to:
  /// **'{time} — {name}'**
  String appointmentTimeName(Object time, Object name);

  /// No description provided for @newAppointmentTitle.
  ///
  /// In en, this message translates to:
  /// **'New Appointment'**
  String get newAppointmentTitle;

  /// No description provided for @patientCustomerLabel.
  ///
  /// In en, this message translates to:
  /// **'Patient / Customer'**
  String get patientCustomerLabel;

  /// No description provided for @timeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time: {time}'**
  String timeLabel(Object time);

  /// No description provided for @notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesLabel;

  /// No description provided for @optionalHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optionalHint;

  /// No description provided for @saveAppointment.
  ///
  /// In en, this message translates to:
  /// **'Save Appointment'**
  String get saveAppointment;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @periodDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get periodDaily;

  /// No description provided for @periodWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get periodWeekly;

  /// No description provided for @periodMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get periodMonthly;

  /// No description provided for @periodYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get periodYearly;

  /// No description provided for @exportAsPdf.
  ///
  /// In en, this message translates to:
  /// **'Export as PDF'**
  String get exportAsPdf;

  /// No description provided for @exportAsExcel.
  ///
  /// In en, this message translates to:
  /// **'Export as Excel'**
  String get exportAsExcel;

  /// No description provided for @exportComingSoon.
  ///
  /// In en, this message translates to:
  /// **'PDF/Excel export lands in a future batch'**
  String get exportComingSoon;

  /// No description provided for @aiInsightsTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Insights'**
  String get aiInsightsTitle;

  /// No description provided for @notEnoughDataForInsights.
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet to generate insights'**
  String get notEnoughDataForInsights;

  /// No description provided for @scanInvoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Invoice'**
  String get scanInvoiceTitle;

  /// No description provided for @pointCameraAtInvoice.
  ///
  /// In en, this message translates to:
  /// **'Point camera at invoice'**
  String get pointCameraAtInvoice;

  /// No description provided for @keepInvoiceFlatWellLit.
  ///
  /// In en, this message translates to:
  /// **'Keep the invoice flat and well lit'**
  String get keepInvoiceFlatWellLit;

  /// No description provided for @cameraButton.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get cameraButton;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// No description provided for @tryDemoInvoice.
  ///
  /// In en, this message translates to:
  /// **'▶ Try Demo Invoice'**
  String get tryDemoInvoice;

  /// No description provided for @analyzingInvoice.
  ///
  /// In en, this message translates to:
  /// **'Analyzing invoice...'**
  String get analyzingInvoice;

  /// No description provided for @readingTextDetecting.
  ///
  /// In en, this message translates to:
  /// **'Reading text, detecting products and quantities'**
  String get readingTextDetecting;

  /// No description provided for @detectedItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Detected Items'**
  String get detectedItemsTitle;

  /// No description provided for @qtyValue.
  ///
  /// In en, this message translates to:
  /// **'Qty: {qty}'**
  String qtyValue(Object qty);

  /// No description provided for @reviewAndEdit.
  ///
  /// In en, this message translates to:
  /// **'Review & Edit'**
  String get reviewAndEdit;

  /// No description provided for @reviewItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Review Items'**
  String get reviewItemsTitle;

  /// No description provided for @productNameFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Product name'**
  String get productNameFieldLabel;

  /// No description provided for @quantityFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantityFieldLabel;

  /// No description provided for @purchasePriceFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Purchase price'**
  String get purchasePriceFieldLabel;

  /// No description provided for @confirmAddToInventory.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Add to Inventory'**
  String get confirmAddToInventory;

  /// No description provided for @productsAddedToInventory.
  ///
  /// In en, this message translates to:
  /// **'{count} product(s) added to inventory'**
  String productsAddedToInventory(Object count);

  /// No description provided for @noProductsLoadedYet.
  ///
  /// In en, this message translates to:
  /// **'No products loaded yet — check your connection and try again'**
  String get noProductsLoadedYet;

  /// No description provided for @onlyNInStock.
  ///
  /// In en, this message translates to:
  /// **'Only {qty} in stock for {name}'**
  String onlyNInStock(Object qty, Object name);

  /// No description provided for @outOfStockFor.
  ///
  /// In en, this message translates to:
  /// **'{name} is out of stock'**
  String outOfStockFor(Object name);

  /// No description provided for @addAtLeastOneProduct.
  ///
  /// In en, this message translates to:
  /// **'Add at least one product to the cart'**
  String get addAtLeastOneProduct;

  /// No description provided for @saleRecordedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Sale recorded successfully'**
  String get saleRecordedSuccessfully;

  /// No description provided for @couldNotCompleteSale.
  ///
  /// In en, this message translates to:
  /// **'Could not complete sale: {error}'**
  String couldNotCompleteSale(Object error);

  /// No description provided for @newSaleTitle.
  ///
  /// In en, this message translates to:
  /// **'New Sale'**
  String get newSaleTitle;

  /// No description provided for @searchProductOrScan.
  ///
  /// In en, this message translates to:
  /// **'Search product or scan barcode'**
  String get searchProductOrScan;

  /// No description provided for @scanInvoiceChooserTitle.
  ///
  /// In en, this message translates to:
  /// **'Which invoice do you want to scan?'**
  String get scanInvoiceChooserTitle;

  /// No description provided for @scanSalesInvoiceOption.
  ///
  /// In en, this message translates to:
  /// **'Sales Invoice'**
  String get scanSalesInvoiceOption;

  /// No description provided for @scanSalesInvoiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Record a sale from a customer receipt'**
  String get scanSalesInvoiceSubtitle;

  /// No description provided for @scanStockInvoiceOption.
  ///
  /// In en, this message translates to:
  /// **'Stock Invoice'**
  String get scanStockInvoiceOption;

  /// No description provided for @scanStockInvoiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add purchased items to inventory'**
  String get scanStockInvoiceSubtitle;

  /// No description provided for @scanBarcodeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get scanBarcodeTooltip;

  /// No description provided for @barcodeScannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Barcode'**
  String get barcodeScannerTitle;

  /// No description provided for @barcodeScannerHint.
  ///
  /// In en, this message translates to:
  /// **'Align the barcode within the frame'**
  String get barcodeScannerHint;

  /// No description provided for @enterCodeManually.
  ///
  /// In en, this message translates to:
  /// **'Enter code manually'**
  String get enterCodeManually;

  /// No description provided for @manualBarcodeEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter Barcode'**
  String get manualBarcodeEntryTitle;

  /// No description provided for @barcodeNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'No product matches barcode {code}'**
  String barcodeNotFoundMessage(Object code);

  /// No description provided for @addAsNewProductAction.
  ///
  /// In en, this message translates to:
  /// **'Add as new product'**
  String get addAsNewProductAction;

  /// No description provided for @scannedProductAddedToCart.
  ///
  /// In en, this message translates to:
  /// **'{name} added to the cart'**
  String scannedProductAddedToCart(Object name);

  /// No description provided for @matchProductLabel.
  ///
  /// In en, this message translates to:
  /// **'Matched product'**
  String get matchProductLabel;

  /// No description provided for @selectProductHint.
  ///
  /// In en, this message translates to:
  /// **'Select a product'**
  String get selectProductHint;

  /// No description provided for @salesInvoiceReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review Sale Items'**
  String get salesInvoiceReviewTitle;

  /// No description provided for @confirmRecordSale.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Record Sale'**
  String get confirmRecordSale;

  /// No description provided for @saleRecordedFromScan.
  ///
  /// In en, this message translates to:
  /// **'Sale recorded from scanned invoice'**
  String get saleRecordedFromScan;

  /// No description provided for @pleaseMatchAllItems.
  ///
  /// In en, this message translates to:
  /// **'Match every item to a product before continuing'**
  String get pleaseMatchAllItems;

  /// No description provided for @cameraPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required to scan'**
  String get cameraPermissionRequired;

  /// No description provided for @noMatchFound.
  ///
  /// In en, this message translates to:
  /// **'No match found — select manually'**
  String get noMatchFound;

  /// No description provided for @unitPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get unitPriceLabel;

  /// No description provided for @removeItemLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeItemLabel;

  /// No description provided for @barcodeFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Barcode (optional)'**
  String get barcodeFieldLabel;

  /// No description provided for @barcodeFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Scan or type manually'**
  String get barcodeFieldHint;

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cart is empty — add a product above'**
  String get cartEmpty;

  /// No description provided for @cartLineLabel.
  ///
  /// In en, this message translates to:
  /// **'{name} × {qty}'**
  String cartLineLabel(Object name, Object qty);

  /// No description provided for @discountDzdLabel.
  ///
  /// In en, this message translates to:
  /// **'Discount (DZD)'**
  String get discountDzdLabel;

  /// No description provided for @confirmSaleButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm Sale'**
  String get confirmSaleButton;

  /// No description provided for @searchProductDots.
  ///
  /// In en, this message translates to:
  /// **'Search product...'**
  String get searchProductDots;

  /// No description provided for @outOfStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get outOfStockLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
