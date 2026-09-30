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
  /// **'Market / Store'**
  String get businessTypeGrocery;

  /// No description provided for @businessTypeGroceryDesc.
  ///
  /// In en, this message translates to:
  /// **'Supermarket, mini market, grocery, convenience store'**
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
  /// **'Clinic / Medical'**
  String get businessTypeClinic;

  /// No description provided for @businessTypeClinicDesc.
  ///
  /// In en, this message translates to:
  /// **'Patients, appointments — medical & dental'**
  String get businessTypeClinicDesc;

  /// No description provided for @businessTypeRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant / Café'**
  String get businessTypeRestaurant;

  /// No description provided for @businessTypeRestaurantDesc.
  ///
  /// In en, this message translates to:
  /// **'Menu, orders, tables — restaurants & cafés'**
  String get businessTypeRestaurantDesc;

  /// No description provided for @businessTypeCompany.
  ///
  /// In en, this message translates to:
  /// **'Enterprise / Company'**
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
  /// **'Base Salary'**
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
  /// **'Manage personal and business details'**
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

  /// No description provided for @noItemsDetected.
  ///
  /// In en, this message translates to:
  /// **'No items were detected in that photo — try again with better lighting.'**
  String get noItemsDetected;

  /// No description provided for @expensePeriodTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Period type'**
  String get expensePeriodTypeLabel;

  /// No description provided for @periodOneTime.
  ///
  /// In en, this message translates to:
  /// **'One-time'**
  String get periodOneTime;

  /// No description provided for @periodCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get periodCustom;

  /// No description provided for @periodStartLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get periodStartLabel;

  /// No description provided for @periodEndLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get periodEndLabel;

  /// No description provided for @expenseCoversDays.
  ///
  /// In en, this message translates to:
  /// **'Covers {days} day(s)'**
  String expenseCoversDays(Object days);

  /// No description provided for @selectPeriodEndDate.
  ///
  /// In en, this message translates to:
  /// **'Please pick an end date for this custom period'**
  String get selectPeriodEndDate;

  /// No description provided for @selectCustomerFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a customer first'**
  String get selectCustomerFirst;

  /// No description provided for @noCustomersYet.
  ///
  /// In en, this message translates to:
  /// **'No customers yet — add one first'**
  String get noCustomersYet;

  /// No description provided for @amountExceedsTotal.
  ///
  /// In en, this message translates to:
  /// **'Amount to pay cannot exceed the total'**
  String get amountExceedsTotal;

  /// No description provided for @creditSaleTitle.
  ///
  /// In en, this message translates to:
  /// **'New Credit Sale'**
  String get creditSaleTitle;

  /// No description provided for @selectCustomerHint.
  ///
  /// In en, this message translates to:
  /// **'Select a customer'**
  String get selectCustomerHint;

  /// No description provided for @amountToPayNowLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount to Pay Now (DZD)'**
  String get amountToPayNowLabel;

  /// No description provided for @remainingCreditLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining Credit'**
  String get remainingCreditLabel;

  /// No description provided for @confirmCreditSaleButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm Credit Sale'**
  String get confirmCreditSaleButton;

  /// No description provided for @creditSaleRecorded.
  ///
  /// In en, this message translates to:
  /// **'Credit sale recorded'**
  String get creditSaleRecorded;

  /// No description provided for @creditPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get creditPageTitle;

  /// No description provided for @newCreditSaleAction.
  ///
  /// In en, this message translates to:
  /// **'New Credit Sale'**
  String get newCreditSaleAction;

  /// No description provided for @customersWithCreditTitle.
  ///
  /// In en, this message translates to:
  /// **'Customers with outstanding credit'**
  String get customersWithCreditTitle;

  /// No description provided for @noOutstandingCredit.
  ///
  /// In en, this message translates to:
  /// **'No customer currently owes anything'**
  String get noOutstandingCredit;

  /// No description provided for @totalCreditLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Credit'**
  String get totalCreditLabel;

  /// No description provided for @totalPaidLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get totalPaidLabel;

  /// No description provided for @noOutstandingBalanceForCustomer.
  ///
  /// In en, this message translates to:
  /// **'This customer has no outstanding balance'**
  String get noOutstandingBalanceForCustomer;

  /// No description provided for @recordPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get recordPaymentTitle;

  /// No description provided for @currentBalanceHelper.
  ///
  /// In en, this message translates to:
  /// **'Current balance: {balance} DZD'**
  String currentBalanceHelper(Object balance);

  /// No description provided for @paymentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded'**
  String get paymentRecorded;

  /// No description provided for @noTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactionsYet;

  /// No description provided for @creditPurchaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Credit Purchase'**
  String get creditPurchaseLabel;

  /// No description provided for @paymentLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentLabel;

  /// No description provided for @balanceAfterLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance after: {balance} DZD'**
  String balanceAfterLabel(Object balance);

  /// No description provided for @clinicDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Clinic Dashboard'**
  String get clinicDashboardTitle;

  /// No description provided for @patientsTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Patients Today'**
  String get patientsTodayLabel;

  /// No description provided for @appointmentsTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Appointments Today'**
  String get appointmentsTodayLabel;

  /// No description provided for @waitingLabel.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get waitingLabel;

  /// No description provided for @completedTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed Today'**
  String get completedTodayLabel;

  /// No description provided for @noShowTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'No-Shows Today'**
  String get noShowTodayLabel;

  /// No description provided for @newPatientsTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'New Patients Today'**
  String get newPatientsTodayLabel;

  /// No description provided for @doctorsLabel.
  ///
  /// In en, this message translates to:
  /// **'Doctors'**
  String get doctorsLabel;

  /// No description provided for @clinicQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting Room'**
  String get clinicQueueTitle;

  /// No description provided for @callNextPatientButton.
  ///
  /// In en, this message translates to:
  /// **'Call Next Patient'**
  String get callNextPatientButton;

  /// No description provided for @nextPatientLabel.
  ///
  /// In en, this message translates to:
  /// **'Next Patient: {name}'**
  String nextPatientLabel(Object name);

  /// No description provided for @noOneWaitingMessage.
  ///
  /// In en, this message translates to:
  /// **'No one is waiting right now'**
  String get noOneWaitingMessage;

  /// No description provided for @completeConsultationButton.
  ///
  /// In en, this message translates to:
  /// **'Complete Consultation'**
  String get completeConsultationButton;

  /// No description provided for @clinicPatientsTitle.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get clinicPatientsTitle;

  /// No description provided for @addPatientTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Patient'**
  String get addPatientTitle;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullNameLabel;

  /// No description provided for @genderLabel.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get genderLabel;

  /// No description provided for @dateOfBirthLabel.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get dateOfBirthLabel;

  /// No description provided for @savePatient.
  ///
  /// In en, this message translates to:
  /// **'Save Patient'**
  String get savePatient;

  /// No description provided for @patientProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Patient Profile'**
  String get patientProfileTitle;

  /// No description provided for @visitHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Visit History'**
  String get visitHistoryTitle;

  /// No description provided for @noVisitsYetMessage.
  ///
  /// In en, this message translates to:
  /// **'No visits recorded yet'**
  String get noVisitsYetMessage;

  /// No description provided for @diagnosisLabel.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis'**
  String get diagnosisLabel;

  /// No description provided for @treatmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Treatment'**
  String get treatmentLabel;

  /// No description provided for @prescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get prescriptionLabel;

  /// No description provided for @followUpDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Follow-up date'**
  String get followUpDateLabel;

  /// No description provided for @addToQueueAction.
  ///
  /// In en, this message translates to:
  /// **'Add to Queue'**
  String get addToQueueAction;

  /// No description provided for @selectPatientTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Patient'**
  String get selectPatientTitle;

  /// No description provided for @searchPatientsHint.
  ///
  /// In en, this message translates to:
  /// **'Search patients...'**
  String get searchPatientsHint;

  /// No description provided for @noPatientsFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'No patients found'**
  String get noPatientsFoundMessage;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @documentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Medical Documents'**
  String get documentsTitle;

  /// No description provided for @addDocumentAction.
  ///
  /// In en, this message translates to:
  /// **'Add Document'**
  String get addDocumentAction;

  /// No description provided for @documentNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Document name'**
  String get documentNameLabel;

  /// No description provided for @documentTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Document type'**
  String get documentTypeLabel;

  /// No description provided for @fileUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'File URL'**
  String get fileUrlLabel;

  /// No description provided for @noDocumentsYetMessage.
  ///
  /// In en, this message translates to:
  /// **'No documents yet'**
  String get noDocumentsYetMessage;

  /// No description provided for @confirmDeleteDocumentMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete this document?'**
  String get confirmDeleteDocumentMessage;

  /// No description provided for @documentDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Document deleted'**
  String get documentDeletedMessage;

  /// No description provided for @documentAddedMessage.
  ///
  /// In en, this message translates to:
  /// **'Document added'**
  String get documentAddedMessage;

  /// No description provided for @prescriptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions'**
  String get prescriptionsTitle;

  /// No description provided for @newPrescriptionAction.
  ///
  /// In en, this message translates to:
  /// **'New Prescription'**
  String get newPrescriptionAction;

  /// No description provided for @noPrescriptionsYetMessage.
  ///
  /// In en, this message translates to:
  /// **'No prescriptions yet'**
  String get noPrescriptionsYetMessage;

  /// No description provided for @medicationNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Medication name'**
  String get medicationNameLabel;

  /// No description provided for @dosageLabel.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get dosageLabel;

  /// No description provided for @frequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequencyLabel;

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get durationLabel;

  /// No description provided for @instructionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get instructionsLabel;

  /// No description provided for @addMedicationAction.
  ///
  /// In en, this message translates to:
  /// **'Add Medication'**
  String get addMedicationAction;

  /// No description provided for @savePrescriptionAction.
  ///
  /// In en, this message translates to:
  /// **'Save Prescription'**
  String get savePrescriptionAction;

  /// No description provided for @prescriptionSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Prescription saved'**
  String get prescriptionSavedMessage;

  /// No description provided for @prescriptionNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Prescription No.'**
  String get prescriptionNumberLabel;

  /// No description provided for @medicationRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'At least one medication is required'**
  String get medicationRequiredMessage;

  /// No description provided for @patientAddedMessage.
  ///
  /// In en, this message translates to:
  /// **'Patient added'**
  String get patientAddedMessage;

  /// No description provided for @queueEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'The waiting room is empty'**
  String get queueEmptyMessage;

  /// No description provided for @consultationPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Consultation Price'**
  String get consultationPriceLabel;

  /// No description provided for @amountPaidLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount Paid'**
  String get amountPaidLabel;

  /// No description provided for @markFullyPaidLabel.
  ///
  /// In en, this message translates to:
  /// **'Mark as fully paid'**
  String get markFullyPaidLabel;

  /// No description provided for @remainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remainingLabel;

  /// No description provided for @invoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoiceTitle;

  /// No description provided for @paymentStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment status'**
  String get paymentStatusLabel;

  /// No description provided for @orderDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Order Details'**
  String get orderDetailsTitle;

  /// No description provided for @paidAmountShortLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paidAmountShortLabel;

  /// No description provided for @updateStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Update Status'**
  String get updateStatusLabel;

  /// No description provided for @restaurantRecordPaymentAction.
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get restaurantRecordPaymentAction;

  /// No description provided for @paymentRecordedMessage.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded'**
  String get paymentRecordedMessage;

  /// No description provided for @enterValidAmountMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get enterValidAmountMessage;

  /// No description provided for @confirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmAction;

  /// No description provided for @addInventoryItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Inventory Item'**
  String get addInventoryItemTitle;

  /// No description provided for @applyAction.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyAction;

  /// No description provided for @minStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Min. stock'**
  String get minStockLabel;

  /// No description provided for @noInventoryItemsMessage.
  ///
  /// In en, this message translates to:
  /// **'No inventory items'**
  String get noInventoryItemsMessage;

  /// No description provided for @openingQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Opening qty'**
  String get openingQuantityLabel;

  /// No description provided for @removeAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeAction;

  /// No description provided for @searchInventoryHint.
  ///
  /// In en, this message translates to:
  /// **'Search inventory...'**
  String get searchInventoryHint;

  /// No description provided for @supplierLabel.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get supplierLabel;

  /// No description provided for @unitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unitLabel;

  /// No description provided for @lowStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get lowStockLabel;

  /// No description provided for @enterNonZeroAmountMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a non-zero amount'**
  String get enterNonZeroAmountMessage;

  /// No description provided for @manualAdjustmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Manual adjustment'**
  String get manualAdjustmentLabel;

  /// No description provided for @inventoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventoryTitle;

  /// No description provided for @saveRecipeAction.
  ///
  /// In en, this message translates to:
  /// **'Save Recipe'**
  String get saveRecipeAction;

  /// No description provided for @addAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addAction;

  /// No description provided for @ordersTitle.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get ordersTitle;

  /// No description provided for @noActiveOrdersMessage.
  ///
  /// In en, this message translates to:
  /// **'No active orders right now'**
  String get noActiveOrdersMessage;

  /// No description provided for @moveToNextStageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Move to next stage'**
  String get moveToNextStageTooltip;

  /// No description provided for @cancelOrderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get cancelOrderTooltip;

  /// No description provided for @takeawayLabel.
  ///
  /// In en, this message translates to:
  /// **'Takeaway'**
  String get takeawayLabel;

  /// No description provided for @newOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'New Order'**
  String get newOrderTitle;

  /// No description provided for @tableOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Table (optional — takeaway if empty)'**
  String get tableOptionalLabel;

  /// No description provided for @takeawayNoTableOption.
  ///
  /// In en, this message translates to:
  /// **'Takeaway / no table'**
  String get takeawayNoTableOption;

  /// No description provided for @noMenuItemsYetMessage.
  ///
  /// In en, this message translates to:
  /// **'No menu items yet — add some from the Menu screen'**
  String get noMenuItemsYetMessage;

  /// No description provided for @addAtLeastOneItemMessage.
  ///
  /// In en, this message translates to:
  /// **'Add at least one item'**
  String get addAtLeastOneItemMessage;

  /// No description provided for @orderCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Order created'**
  String get orderCreatedMessage;

  /// No description provided for @createOrderAction.
  ///
  /// In en, this message translates to:
  /// **'Create Order'**
  String get createOrderAction;

  /// No description provided for @tablesTitle.
  ///
  /// In en, this message translates to:
  /// **'Tables'**
  String get tablesTitle;

  /// No description provided for @addTableTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Table'**
  String get addTableTitle;

  /// No description provided for @tableNameFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Table name / number'**
  String get tableNameFieldLabel;

  /// No description provided for @seatsLabel.
  ///
  /// In en, this message translates to:
  /// **'Seats'**
  String get seatsLabel;

  /// No description provided for @noTablesYetMessage.
  ///
  /// In en, this message translates to:
  /// **'No tables yet'**
  String get noTablesYetMessage;

  /// No description provided for @saveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAction;

  /// No description provided for @reservationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reservations'**
  String get reservationsTitle;

  /// No description provided for @newReservationTitle.
  ///
  /// In en, this message translates to:
  /// **'New Reservation'**
  String get newReservationTitle;

  /// No description provided for @customerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer name'**
  String get customerNameLabel;

  /// No description provided for @partySizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Party size'**
  String get partySizeLabel;

  /// No description provided for @noReservationsYetMessage.
  ///
  /// In en, this message translates to:
  /// **'No reservations yet'**
  String get noReservationsYetMessage;

  /// No description provided for @seatAction.
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get seatAction;

  /// No description provided for @menuTitle.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menuTitle;

  /// No description provided for @addMenuItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Menu Item'**
  String get addMenuItemTitle;

  /// No description provided for @dishNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Dish name'**
  String get dishNameLabel;

  /// No description provided for @categoryOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Category (optional)'**
  String get categoryOptionalLabel;

  /// No description provided for @priceDzdLabel.
  ///
  /// In en, this message translates to:
  /// **'Price (DZD)'**
  String get priceDzdLabel;

  /// No description provided for @enterValidPriceMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price'**
  String get enterValidPriceMessage;

  /// No description provided for @recipeIngredientsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Recipe (ingredients)'**
  String get recipeIngredientsTooltip;

  /// No description provided for @noShowLabel.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get noShowLabel;

  /// No description provided for @dateTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get dateTimeLabel;

  /// No description provided for @guestsLabel.
  ///
  /// In en, this message translates to:
  /// **'guests'**
  String get guestsLabel;

  /// No description provided for @adjustItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust {itemName}'**
  String adjustItemTitle(Object itemName);

  /// No description provided for @adjustQuantityHint.
  ///
  /// In en, this message translates to:
  /// **'Change ({unit}) — negative to remove'**
  String adjustQuantityHint(Object unit);

  /// No description provided for @todayRevenueLabel.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Revenue'**
  String get todayRevenueLabel;

  /// No description provided for @todayProfitLabel.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Profit'**
  String get todayProfitLabel;

  /// No description provided for @outstandingPaymentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Outstanding Payments'**
  String get outstandingPaymentsLabel;

  /// No description provided for @paymentStatusPaidLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paymentStatusPaidLabel;

  /// No description provided for @paymentStatusPartialLabel.
  ///
  /// In en, this message translates to:
  /// **'Partially Paid'**
  String get paymentStatusPartialLabel;

  /// No description provided for @paymentStatusUnpaidLabel.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get paymentStatusUnpaidLabel;

  /// No description provided for @paymentStatusRefundedLabel.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get paymentStatusRefundedLabel;

  /// No description provided for @clinicRecordPaymentAction.
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get clinicRecordPaymentAction;

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

  /// No description provided for @storeDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Store Dashboard'**
  String get storeDashboardTitle;

  /// No description provided for @pharmacyDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy Dashboard'**
  String get pharmacyDashboardTitle;

  /// No description provided for @customerDebtLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer debt'**
  String get customerDebtLabel;

  /// No description provided for @stockValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Stock value'**
  String get stockValueLabel;

  /// No description provided for @expiringSoonLabel.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get expiringSoonLabel;

  /// No description provided for @inventoryValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Inventory value'**
  String get inventoryValueLabel;

  /// No description provided for @kpiSubtitleDzdToday.
  ///
  /// In en, this message translates to:
  /// **'DZD today'**
  String get kpiSubtitleDzdToday;

  /// No description provided for @kpiSubtitleNetToday.
  ///
  /// In en, this message translates to:
  /// **'Net, today'**
  String get kpiSubtitleNetToday;

  /// No description provided for @transactionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactionsLabel;

  /// No description provided for @stockAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock Alerts'**
  String get stockAlertsTitle;

  /// No description provided for @noStockAlertsMessage.
  ///
  /// In en, this message translates to:
  /// **'No stock alerts right now'**
  String get noStockAlertsMessage;

  /// No description provided for @noStockOrExpiryAlertsMessage.
  ///
  /// In en, this message translates to:
  /// **'No stock or expiry alerts right now'**
  String get noStockOrExpiryAlertsMessage;

  /// No description provided for @customerDebtTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer Debt'**
  String get customerDebtTitle;

  /// No description provided for @noOutstandingDebtMessage.
  ///
  /// In en, this message translates to:
  /// **'No outstanding customer debt'**
  String get noOutstandingDebtMessage;

  /// No description provided for @stockByCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock by Category'**
  String get stockByCategoryTitle;

  /// No description provided for @noProductsYetMessage.
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get noProductsYetMessage;

  /// No description provided for @expirationDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Expiration date'**
  String get expirationDateLabel;

  /// No description provided for @selectDateHint.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDateHint;

  /// No description provided for @clearDateAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearDateAction;

  /// No description provided for @sizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sizeLabel;

  /// No description provided for @colorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get colorLabel;

  /// No description provided for @brandLabel.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get brandLabel;

  /// No description provided for @editProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get editProductTitle;

  /// No description provided for @editAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editAction;

  /// No description provided for @saveChangesAction.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChangesAction;

  /// No description provided for @productUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Product updated'**
  String get productUpdatedMessage;

  /// No description provided for @goodDay.
  ///
  /// In en, this message translates to:
  /// **'Good day'**
  String get goodDay;

  /// No description provided for @companyDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Company Dashboard'**
  String get companyDashboardTitle;

  /// No description provided for @openProjectsLabel.
  ///
  /// In en, this message translates to:
  /// **'Open projects'**
  String get openProjectsLabel;

  /// No description provided for @dzdThisMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'DZD this month'**
  String get dzdThisMonthLabel;

  /// No description provided for @thisMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonthLabel;

  /// No description provided for @netProfitLabel.
  ///
  /// In en, this message translates to:
  /// **'Net profit'**
  String get netProfitLabel;

  /// No description provided for @salariesLabel.
  ///
  /// In en, this message translates to:
  /// **'Salaries'**
  String get salariesLabel;

  /// No description provided for @todayRevenueProfit.
  ///
  /// In en, this message translates to:
  /// **'Today: {revenue} revenue · {profit} profit'**
  String todayRevenueProfit(Object revenue, Object profit);

  /// No description provided for @projectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projectsTitle;

  /// No description provided for @noOpenProjectsMessage.
  ///
  /// In en, this message translates to:
  /// **'No open projects'**
  String get noOpenProjectsMessage;

  /// No description provided for @overdueCount.
  ///
  /// In en, this message translates to:
  /// **'{count} overdue'**
  String overdueCount(Object count);

  /// No description provided for @unpaidInvoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Unpaid Invoices'**
  String get unpaidInvoicesTitle;

  /// No description provided for @noUnpaidInvoicesMessage.
  ///
  /// In en, this message translates to:
  /// **'No unpaid invoices'**
  String get noUnpaidInvoicesMessage;

  /// No description provided for @clientCreditBalancesMessage.
  ///
  /// In en, this message translates to:
  /// **'Client credit balances: {amount}'**
  String clientCreditBalancesMessage(Object amount);

  /// No description provided for @noProjectsYetMessage.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get noProjectsYetMessage;

  /// No description provided for @dueDateBeforeStartDateError.
  ///
  /// In en, this message translates to:
  /// **'Due date cannot be before the start date'**
  String get dueDateBeforeStartDateError;

  /// No description provided for @newProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'New Project'**
  String get newProjectTitle;

  /// No description provided for @projectNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Project name'**
  String get projectNameLabel;

  /// No description provided for @clientOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Client (optional)'**
  String get clientOptionalLabel;

  /// No description provided for @noClientOption.
  ///
  /// In en, this message translates to:
  /// **'No client'**
  String get noClientOption;

  /// No description provided for @budgetDzdOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Budget (DZD, optional)'**
  String get budgetDzdOptionalLabel;

  /// No description provided for @descriptionOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptionalLabel;

  /// No description provided for @startDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDateLabel;

  /// No description provided for @dueDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get dueDateLabel;

  /// No description provided for @restaurantDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Dashboard'**
  String get restaurantDashboardTitle;

  /// No description provided for @tablesOccupiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Tables occupied'**
  String get tablesOccupiedLabel;

  /// No description provided for @reservationsTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Reservations today'**
  String get reservationsTodayLabel;

  /// No description provided for @todaysOrdersLabel.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Orders'**
  String get todaysOrdersLabel;

  /// No description provided for @activeOrdersLabel.
  ///
  /// In en, this message translates to:
  /// **'Active Orders'**
  String get activeOrdersLabel;

  /// No description provided for @inProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get inProgressLabel;

  /// No description provided for @pendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String pendingCount(Object count);

  /// No description provided for @preparingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} preparing'**
  String preparingCount(Object count);

  /// No description provided for @readyCount.
  ///
  /// In en, this message translates to:
  /// **'{count} ready'**
  String readyCount(Object count);

  /// No description provided for @clothingProductsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clothing Products'**
  String get clothingProductsTitle;

  /// No description provided for @viewAllAction.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAllAction;

  /// No description provided for @noClothingProductsMessage.
  ///
  /// In en, this message translates to:
  /// **'No clothing products added yet'**
  String get noClothingProductsMessage;

  /// No description provided for @expiresOnLabel.
  ///
  /// In en, this message translates to:
  /// **'expires {date}'**
  String expiresOnLabel(Object date);

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {item}'**
  String deleteConfirmTitle(Object item);

  /// No description provided for @deleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this {item}?'**
  String deleteConfirmMessage(Object item);

  /// No description provided for @serverSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Server Settings'**
  String get serverSettingsTitle;

  /// No description provided for @serverBaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Server Base URL'**
  String get serverBaseUrlLabel;

  /// No description provided for @testConnectionAction.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnectionAction;

  /// No description provided for @editExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Expense'**
  String get editExpenseTitle;

  /// No description provided for @updateExpenseAction.
  ///
  /// In en, this message translates to:
  /// **'Update Expense'**
  String get updateExpenseAction;

  /// No description provided for @editMenuItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Menu Item'**
  String get editMenuItemTitle;

  /// No description provided for @recipeTitle.
  ///
  /// In en, this message translates to:
  /// **'Recipe — {name}'**
  String recipeTitle(Object name);

  /// No description provided for @quantityRequiredUnit.
  ///
  /// In en, this message translates to:
  /// **'Quantity required ({unit})'**
  String quantityRequiredUnit(Object unit);

  /// No description provided for @enterValidQuantityFor.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid quantity for {name}'**
  String enterValidQuantityFor(Object name);

  /// No description provided for @noPastOrdersFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'No past orders found'**
  String get noPastOrdersFoundMessage;

  /// No description provided for @deleteMenuItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Menu Item'**
  String get deleteMenuItemTitle;

  /// No description provided for @deleteSupplierTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Supplier'**
  String get deleteSupplierTitle;

  /// No description provided for @deleteCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Customer'**
  String get deleteCustomerTitle;

  /// No description provided for @deleteEmployeeTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Employee'**
  String get deleteEmployeeTitle;

  /// No description provided for @deleteExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Expense'**
  String get deleteExpenseTitle;

  /// No description provided for @deleteProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Product'**
  String get deleteProductTitle;

  /// No description provided for @supplierFallback.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get supplierFallback;

  /// No description provided for @customerFallback.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customerFallback;

  /// No description provided for @expenseFallback.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expenseFallback;

  /// No description provided for @personalProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal Profile'**
  String get personalProfileTitle;

  /// No description provided for @saveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save Profile'**
  String get saveProfile;

  /// No description provided for @profileUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdatedSuccess;

  /// No description provided for @errorUpdatingProfile.
  ///
  /// In en, this message translates to:
  /// **'Error updating profile: {error}'**
  String errorUpdatingProfile(Object error);

  /// No description provided for @businessInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Business Information'**
  String get businessInfoTitle;

  /// No description provided for @updateBusinessInfo.
  ///
  /// In en, this message translates to:
  /// **'Update Business Info'**
  String get updateBusinessInfo;

  /// No description provided for @businessInfoUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Business information updated successfully'**
  String get businessInfoUpdatedSuccess;

  /// No description provided for @errorUpdatingBusiness.
  ///
  /// In en, this message translates to:
  /// **'Error updating business info: {error}'**
  String errorUpdatingBusiness(Object error);

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordTitle;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// No description provided for @enterCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter current password'**
  String get enterCurrentPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// No description provided for @confirmYourNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm your new password'**
  String get confirmYourNewPassword;

  /// No description provided for @updatePasswordAction.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePasswordAction;

  /// No description provided for @passwordChangedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get passwordChangedSuccess;

  /// No description provided for @errorChangingPassword.
  ///
  /// In en, this message translates to:
  /// **'Error changing password: {error}'**
  String errorChangingPassword(Object error);

  /// No description provided for @dangerZoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZoneTitle;

  /// No description provided for @deleteAccountPermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete Account Permanently'**
  String get deleteAccountPermanently;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account will permanently delete your profile, business settings, products, sales, and invoices. This action cannot be undone.'**
  String get deleteAccountWarning;

  /// No description provided for @enterPasswordToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to confirm'**
  String get enterPasswordToConfirm;

  /// No description provided for @deletePermanentlyAction.
  ///
  /// In en, this message translates to:
  /// **'Delete Permanently'**
  String get deletePermanentlyAction;

  /// No description provided for @accountDeletionFailed.
  ///
  /// In en, this message translates to:
  /// **'Account deletion failed: {error}'**
  String accountDeletionFailed(Object error);

  /// No description provided for @failedToPickImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick image: {error}'**
  String failedToPickImage(Object error);

  /// No description provided for @businessPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Business Phone'**
  String get businessPhoneLabel;

  /// No description provided for @businessAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Business Address'**
  String get businessAddressLabel;

  /// No description provided for @businessNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Business name is required'**
  String get businessNameRequired;

  /// No description provided for @reportRevenueLabel.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get reportRevenueLabel;

  /// No description provided for @reportExpensesLabel.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get reportExpensesLabel;

  /// No description provided for @reportNetProfitLabel.
  ///
  /// In en, this message translates to:
  /// **'Net Profit'**
  String get reportNetProfitLabel;

  /// No description provided for @salesCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Sales count'**
  String get salesCountLabel;

  /// No description provided for @salesCountInPeriod.
  ///
  /// In en, this message translates to:
  /// **'{count} sale(s) in this period'**
  String salesCountInPeriod(Object count);

  /// No description provided for @topProductsTitle.
  ///
  /// In en, this message translates to:
  /// **'Top Products'**
  String get topProductsTitle;

  /// No description provided for @unitsSoldLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} sold'**
  String unitsSoldLabel(Object count);

  /// No description provided for @noActivityInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No activity recorded for this period yet'**
  String get noActivityInPeriod;

  /// No description provided for @aiActiveSnack.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant & OCR Scanner Active'**
  String get aiActiveSnack;

  /// No description provided for @businessTypeRetail.
  ///
  /// In en, this message translates to:
  /// **'General Retail Store'**
  String get businessTypeRetail;

  /// No description provided for @financialOverview.
  ///
  /// In en, this message translates to:
  /// **'Financial Overview'**
  String get financialOverview;

  /// No description provided for @revenueBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Revenue Breakdown'**
  String get revenueBreakdownTitle;

  /// No description provided for @expensesBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Expense Breakdown'**
  String get expensesBreakdownTitle;

  /// No description provided for @operatingExpensesLabel.
  ///
  /// In en, this message translates to:
  /// **'Business Expenses'**
  String get operatingExpensesLabel;

  /// No description provided for @employeeSalariesLabel.
  ///
  /// In en, this message translates to:
  /// **'Employee Salaries'**
  String get employeeSalariesLabel;

  /// No description provided for @totalExpensesLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Expenses'**
  String get totalExpensesLabel;

  /// No description provided for @profitCalculationTitle.
  ///
  /// In en, this message translates to:
  /// **'Profit Calculation'**
  String get profitCalculationTitle;

  /// No description provided for @profitMarginLabel.
  ///
  /// In en, this message translates to:
  /// **'Profit Margin'**
  String get profitMarginLabel;

  /// No description provided for @netLossLabel.
  ///
  /// In en, this message translates to:
  /// **'Net Loss'**
  String get netLossLabel;

  /// No description provided for @activitySummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity Summary'**
  String get activitySummaryTitle;

  /// No description provided for @invoicesCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoicesCountLabel;

  /// No description provided for @expensesCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesCountLabel;

  /// No description provided for @employeesCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get employeesCountLabel;

  /// No description provided for @recentTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactionsTitle;

  /// No description provided for @noTransactionsInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No transactions in this period'**
  String get noTransactionsInPeriod;

  /// No description provided for @coreSalesLabel.
  ///
  /// In en, this message translates to:
  /// **'Direct Sales'**
  String get coreSalesLabel;

  /// No description provided for @creditPaymentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Credit Payments'**
  String get creditPaymentsLabel;

  /// No description provided for @categoryBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses by Category'**
  String get categoryBreakdownTitle;

  /// No description provided for @employeeBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Salaries by Employee'**
  String get employeeBreakdownTitle;

  /// No description provided for @noEmployeesFound.
  ///
  /// In en, this message translates to:
  /// **'No employees registered'**
  String get noEmployeesFound;

  /// No description provided for @noExpensesFound.
  ///
  /// In en, this message translates to:
  /// **'No business expenses recorded'**
  String get noExpensesFound;

  /// No description provided for @profitFormulaExplanation.
  ///
  /// In en, this message translates to:
  /// **'Net Profit = Total Revenue - Total Expenses'**
  String get profitFormulaExplanation;

  /// No description provided for @dateRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get dateRangeLabel;

  /// No description provided for @scanStageUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading invoice image...'**
  String get scanStageUploading;

  /// No description provided for @scanStageOcr.
  ///
  /// In en, this message translates to:
  /// **'Running OCR text recognition...'**
  String get scanStageOcr;

  /// No description provided for @scanStageExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting products and prices...'**
  String get scanStageExtracting;

  /// No description provided for @scanStageFinalizing.
  ///
  /// In en, this message translates to:
  /// **'Finalizing extracted invoice items...'**
  String get scanStageFinalizing;

  /// No description provided for @scanTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'Invoice scanning timed out. Please try again or verify AI connection.'**
  String get scanTimeoutMessage;

  /// No description provided for @scanCancelledMessage.
  ///
  /// In en, this message translates to:
  /// **'Invoice scan was cancelled.'**
  String get scanCancelledMessage;

  /// No description provided for @retryScanAction.
  ///
  /// In en, this message translates to:
  /// **'Retry Scan'**
  String get retryScanAction;

  /// No description provided for @aiServiceDisabledMessage.
  ///
  /// In en, this message translates to:
  /// **'AI services are currently disabled. Please enable them in Settings.'**
  String get aiServiceDisabledMessage;

  /// No description provided for @aiServiceUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'AI server is unreachable. Check your AI server connection in Settings.'**
  String get aiServiceUnavailableMessage;

  /// No description provided for @scanFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Failed'**
  String get scanFailedTitle;

  /// No description provided for @scanSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice Scanned Successfully'**
  String get scanSuccessTitle;

  /// No description provided for @cancelScanAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel Scan'**
  String get cancelScanAction;

  /// No description provided for @aiStatusOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get aiStatusOnline;

  /// No description provided for @aiStatusDegraded.
  ///
  /// In en, this message translates to:
  /// **'Degraded (Missing Models)'**
  String get aiStatusDegraded;

  /// No description provided for @aiStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get aiStatusOffline;

  /// No description provided for @aiStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get aiStatusDisabled;

  /// No description provided for @aiEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable AI Features'**
  String get aiEnabledLabel;

  /// No description provided for @aiEnabledDescription.
  ///
  /// In en, this message translates to:
  /// **'Use local AI for invoice scanning, OCR, and smart business insights'**
  String get aiEnabledDescription;

  /// No description provided for @aiServerUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'AI Server URL'**
  String get aiServerUrlLabel;

  /// No description provided for @aiServerUrlHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. http://10.0.2.2:11434/v1'**
  String get aiServerUrlHint;

  /// No description provided for @aiOcrModelLabel.
  ///
  /// In en, this message translates to:
  /// **'OCR Model'**
  String get aiOcrModelLabel;

  /// No description provided for @aiVisionModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Vision Model'**
  String get aiVisionModelLabel;

  /// No description provided for @aiChatModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Assistant / Chat Model'**
  String get aiChatModelLabel;

  /// No description provided for @testAiConnectionAction.
  ///
  /// In en, this message translates to:
  /// **'Test AI Connection'**
  String get testAiConnectionAction;

  /// No description provided for @aiConnectionSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Successfully connected to AI server'**
  String get aiConnectionSuccessMessage;

  /// No description provided for @aiConnectionFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {error}'**
  String aiConnectionFailedMessage(Object error);

  /// No description provided for @availableModelsLabel.
  ///
  /// In en, this message translates to:
  /// **'Available Models on Server'**
  String get availableModelsLabel;

  /// No description provided for @missingModelsLabel.
  ///
  /// In en, this message translates to:
  /// **'Missing Models'**
  String get missingModelsLabel;

  /// No description provided for @saveAiSettingsAction.
  ///
  /// In en, this message translates to:
  /// **'Save AI Settings'**
  String get saveAiSettingsAction;

  /// No description provided for @aiSettingsSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'AI settings saved successfully'**
  String get aiSettingsSavedSuccess;

  /// No description provided for @couldNotLoadSalesTrend.
  ///
  /// In en, this message translates to:
  /// **'Could not load sales trend'**
  String get couldNotLoadSalesTrend;

  /// No description provided for @askAboutYourBusiness.
  ///
  /// In en, this message translates to:
  /// **'Ask about your business'**
  String get askAboutYourBusiness;

  /// No description provided for @aiAnswersComputedLive.
  ///
  /// In en, this message translates to:
  /// **'Answers are computed live from your real data'**
  String get aiAnswersComputedLive;

  /// No description provided for @changeStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Status'**
  String get changeStatusTitle;

  /// No description provided for @deleteProductTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete Product'**
  String get deleteProductTooltip;

  /// No description provided for @projectStatusPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get projectStatusPlanned;

  /// No description provided for @projectStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get projectStatusInProgress;

  /// No description provided for @projectStatusOnHold.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get projectStatusOnHold;

  /// No description provided for @projectStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get projectStatusCompleted;

  /// No description provided for @projectStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get projectStatusCancelled;

  /// No description provided for @projectStatusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get projectStatusOverdue;

  /// No description provided for @globalNetProfitTitle.
  ///
  /// In en, this message translates to:
  /// **'Global Net Profit'**
  String get globalNetProfitTitle;

  /// No description provided for @allRevenueLabel.
  ///
  /// In en, this message translates to:
  /// **'All Revenue'**
  String get allRevenueLabel;

  /// No description provided for @allExpensesLabel.
  ///
  /// In en, this message translates to:
  /// **'All Expenses'**
  String get allExpensesLabel;

  /// No description provided for @globalBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'All-Time Balance'**
  String get globalBalanceLabel;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @selectMonth.
  ///
  /// In en, this message translates to:
  /// **'Select Month'**
  String get selectMonth;

  /// No description provided for @selectYear.
  ///
  /// In en, this message translates to:
  /// **'Select Year'**
  String get selectYear;

  /// No description provided for @salaryPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Salary Period'**
  String get salaryPeriodLabel;

  /// No description provided for @paymentDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Date'**
  String get paymentDateLabel;

  /// No description provided for @paySalary.
  ///
  /// In en, this message translates to:
  /// **'Pay Salary'**
  String get paySalary;

  /// No description provided for @recordSalaryPayment.
  ///
  /// In en, this message translates to:
  /// **'Record Salary Payment'**
  String get recordSalaryPayment;

  /// No description provided for @duplicateSalaryWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Salary Already Paid'**
  String get duplicateSalaryWarningTitle;

  /// No description provided for @duplicateSalaryWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'A salary payment for this employee for this period already exists. Are you sure you want to record another payment?'**
  String get duplicateSalaryWarningMessage;

  /// No description provided for @monthlyBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly Breakdown'**
  String get monthlyBreakdownTitle;

  /// No description provided for @noTransactionsForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No transactions recorded for this period'**
  String get noTransactionsForPeriod;

  /// No description provided for @salaryExpenseLabel.
  ///
  /// In en, this message translates to:
  /// **'Salary Expenses'**
  String get salaryExpenseLabel;

  /// No description provided for @otherExpensesLabel.
  ///
  /// In en, this message translates to:
  /// **'Other Expenses'**
  String get otherExpensesLabel;

  /// No description provided for @chooseEmployee.
  ///
  /// In en, this message translates to:
  /// **'Choose Employee'**
  String get chooseEmployee;

  /// No description provided for @salaryPaidSuccess.
  ///
  /// In en, this message translates to:
  /// **'Salary payment recorded successfully'**
  String get salaryPaidSuccess;

  /// No description provided for @dailyReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Report'**
  String get dailyReportTitle;

  /// No description provided for @monthlyReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly Report'**
  String get monthlyReportTitle;

  /// No description provided for @yearlyReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Yearly Report'**
  String get yearlyReportTitle;
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
