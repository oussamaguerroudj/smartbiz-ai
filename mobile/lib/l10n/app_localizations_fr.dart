// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Modiri AI';

  @override
  String get onboardingTitle1 => 'Gérez votre activité';

  @override
  String get onboardingDesc1 =>
      'Suivez ventes, stock et bénéfices en un seul endroit, depuis votre téléphone.';

  @override
  String get onboardingTitle2 => 'Suivez votre inventaire';

  @override
  String get onboardingDesc2 =>
      'Ne manquez plus jamais de stock — recevez des alertes avant la rupture.';

  @override
  String get onboardingTitle3 => 'Travaillez plus intelligemment avec l\'IA';

  @override
  String get onboardingDesc3 =>
      'Scannez les factures fournisseurs et interrogez votre assistant IA.';

  @override
  String get skip => 'Passer';

  @override
  String get next => 'Suivant';

  @override
  String get getStarted => 'Commencer';

  @override
  String get loginTitle => 'Content de vous revoir';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Mot de passe';

  @override
  String get rememberMe => 'Se souvenir de moi';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get login => 'Connexion';

  @override
  String get noAccount => 'Pas de compte ? Inscrivez-vous';

  @override
  String get registerTitle => 'Créer un compte';

  @override
  String get fullName => 'Nom complet';

  @override
  String get confirmPassword => 'Confirmer le mot de passe';

  @override
  String get createAccount => 'Créer le compte';

  @override
  String get haveAccount => 'Déjà un compte ? Connexion';

  @override
  String get selectBusinessType => 'Sélectionnez le type d\'activité';

  @override
  String stepOf(Object current, Object total) {
    return 'Étape $current sur $total';
  }

  @override
  String get chooseBusinessTypeHint =>
      'Choisissez l\'option qui correspond le mieux à votre activité';

  @override
  String get businessTypeClothing => 'Boutique de vêtements';

  @override
  String get businessTypeClothingDesc => 'Tailles, couleurs, code-barres';

  @override
  String get businessTypeGrocery => 'Épicerie';

  @override
  String get businessTypeGroceryDesc => 'Péremption, fournisseurs';

  @override
  String get businessTypePharmacy => 'Pharmacie';

  @override
  String get businessTypePharmacyDesc => 'Stock, alertes de péremption';

  @override
  String get businessTypeClinic => 'Clinique / Médecin';

  @override
  String get businessTypeClinicDesc => 'Patients, rendez-vous';

  @override
  String get businessTypeRestaurant => 'Restaurant';

  @override
  String get businessTypeRestaurantDesc => 'Menu, ingrédients';

  @override
  String get businessTypeCompany => 'Entreprise';

  @override
  String get businessTypeCompanyDesc => 'Employés, factures';

  @override
  String get businessTypeWorkshop => 'Atelier / Artisan';

  @override
  String get businessTypeWorkshopDesc => 'Commandes, services';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get businessSetupTitle => 'Configuration de l\'activité';

  @override
  String get businessName => 'Nom de l\'activité';

  @override
  String get businessNameHint => 'ex. Épicerie Amine';

  @override
  String get businessTypeLabel => 'Type d\'activité';

  @override
  String get phoneNumber => 'Numéro de téléphone';

  @override
  String get address => 'Adresse';

  @override
  String get addressHint => 'Ville, rue';

  @override
  String get currency => 'Devise';

  @override
  String get finishSetup => 'Terminer la configuration';

  @override
  String get navDashboard => 'Tableau de bord';

  @override
  String get navSales => 'Ventes';

  @override
  String get navInventory => 'Inventaire';

  @override
  String get navMore => 'Plus';

  @override
  String get moreInvoices => 'Factures';

  @override
  String get moreExpenses => 'Dépenses';

  @override
  String get moreEmployees => 'Employés';

  @override
  String get moreAppointments => 'Rendez-vous';

  @override
  String get moreReports => 'Rapports';

  @override
  String get moreAiAssistant => 'Assistant IA';

  @override
  String get moreNotifications => 'Notifications';

  @override
  String get moreSettings => 'Paramètres';

  @override
  String get goodMorning => 'Bonjour';

  @override
  String get dashboardRevenue => 'Revenu';

  @override
  String get dashboardProfit => 'Bénéfice';

  @override
  String get dashboardLowStock => 'Stock faible';

  @override
  String dashboardTodayCurrency(Object currency) {
    return 'Aujourd\'hui · $currency';
  }

  @override
  String get dashboardToday => 'Aujourd\'hui';

  @override
  String get dashboardNeedsReview => 'À vérifier';

  @override
  String get dashboardAllGood => 'Tout va bien';

  @override
  String get salesTrend => 'Tendance des ventes';

  @override
  String get rangeWeek => 'Semaine';

  @override
  String get rangeMonth => 'Mois';

  @override
  String get rangeYear => 'Année';

  @override
  String get newSale => 'Nouvelle vente';

  @override
  String get scanInvoice => 'Scanner une facture';

  @override
  String lowStockMessage(Object count) {
    return '$count produit(s) en stock faible';
  }

  @override
  String get noSalesInPeriod => 'Aucune vente enregistrée pour cette période';

  @override
  String get verifyAccountTitle => 'Vérifiez votre compte';

  @override
  String verifyAccountSubtitle(Object email) {
    return 'Nous avons envoyé un code à 6 chiffres à $email';
  }

  @override
  String get verifyCodeLabel => 'Code de vérification';

  @override
  String get verifyEnterFullCode => 'Saisissez le code à 6 chiffres';

  @override
  String get verifyResendCode => 'Renvoyer le code';

  @override
  String verifyResendIn(Object seconds) {
    return 'Renvoyer dans ${seconds}s';
  }

  @override
  String get verifyCodeResent => 'Code envoyé';

  @override
  String get verifyAccountButton => 'Vérifier';

  @override
  String get backToLogin => 'Retour à la connexion';

  @override
  String get networkError =>
      'Impossible de joindre le serveur — vérifiez votre connexion';

  @override
  String get forgotPasswordTitle => 'Mot de passe oublié';

  @override
  String get forgotPasswordSubtitle =>
      'Saisissez votre email et nous vous enverrons un code de réinitialisation';

  @override
  String get sendResetCode => 'Envoyer le code';

  @override
  String resetPasswordSubtitle(Object email) {
    return 'Saisissez le code envoyé à $email et choisissez un nouveau mot de passe';
  }

  @override
  String get newPassword => 'Nouveau mot de passe';

  @override
  String get resetPasswordButton => 'Réinitialiser le mot de passe';

  @override
  String get useAnotherEmail => 'Utiliser un autre email';

  @override
  String get passwordResetSuccess =>
      'Mot de passe réinitialisé — veuillez vous connecter';

  @override
  String get emailRequired => 'L\'email est requis';

  @override
  String get emailInvalid => 'Saisissez un email valide';

  @override
  String get passwordRequired => 'Le mot de passe est requis';

  @override
  String get passwordTooShort => 'Minimum 6 caractères';

  @override
  String get nameRequired => 'Saisissez votre nom complet';

  @override
  String get passwordsDoNotMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get loginSubtitle => 'Connectez-vous à votre tableau de bord';

  @override
  String get yourNameHint => 'Votre nom';

  @override
  String get moreTitle => 'Plus';

  @override
  String get moreCustomers => 'Clients';

  @override
  String get moreSuppliers => 'Fournisseurs';

  @override
  String get moreAiScanner => 'Scanner de factures IA';

  @override
  String get moreAiInsights => 'Analyses IA';

  @override
  String errorPrefix(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get retry => 'Réessayer';

  @override
  String get salesEmptyState =>
      'Aucune vente pour le moment — appuyez sur + pour en enregistrer une';

  @override
  String saleNumberFallback(Object id) {
    return 'Vente n° $id';
  }

  @override
  String get walkInCustomer => 'Client de passage';

  @override
  String saleRowSubtitle(Object customer, Object count) {
    return '$customer · $count article(s)';
  }

  @override
  String get requiredField => 'Requis';

  @override
  String get enterValidAmount => 'Saisissez un montant valide';

  @override
  String get employeesTitle => 'Employés';

  @override
  String get addEmployee => 'Ajouter un employé';

  @override
  String get saveEmployee => 'Enregistrer l\'employé';

  @override
  String get positionLabel => 'Poste';

  @override
  String get baseSalaryLabel => 'Salaire de base (DZD)';

  @override
  String get staffDefault => 'Personnel';

  @override
  String get employeeFallback => 'Employé';

  @override
  String get attendancePresent => 'Présent';

  @override
  String get attendanceAbsent => 'Absent';

  @override
  String get attendanceLate => 'En retard';

  @override
  String get salaryThisMonth => 'Salaire ce mois-ci';

  @override
  String baseSalaryValue(Object amount) {
    return 'Base : $amount';
  }

  @override
  String get markPresent => 'Marquer présent';

  @override
  String get markAbsent => 'Marquer absent';

  @override
  String get invoicesTitle => 'Factures';

  @override
  String get noInvoicesYet => 'Pas encore de factures';

  @override
  String get statusUnpaid => 'Impayée';

  @override
  String get statusPaid => 'Payée';

  @override
  String get invoiceFallback => 'Facture';

  @override
  String get billTo => 'Facturé à';

  @override
  String get itemsLabel => 'Articles';

  @override
  String get totalLabel => 'Total';

  @override
  String lineItemLabel(Object name, Object qty) {
    return '$name × $qty';
  }

  @override
  String get pdfExportNotImplemented =>
      'Export PDF : l\'endpoint existe mais n\'est pas encore implémenté';

  @override
  String get shareViaWhatsapp => 'Partager via WhatsApp';

  @override
  String balanceDue(Object amount) {
    return '$amount DZD dû';
  }

  @override
  String get noBalanceDue => '0 DZD dû';

  @override
  String get addCustomer => 'Ajouter un client';

  @override
  String get saveCustomer => 'Enregistrer le client';

  @override
  String get nameLabel => 'Nom';

  @override
  String get phoneLabel => 'Téléphone';

  @override
  String productsSuppliedCount(Object count) {
    return '$count produits fournis';
  }

  @override
  String get addSupplier => 'Ajouter un fournisseur';

  @override
  String get saveSupplier => 'Enregistrer le fournisseur';

  @override
  String get expensesTitle => 'Dépenses';

  @override
  String get thisMonthTotal => 'Total de ce mois';

  @override
  String get noExpensesYet => 'Aucune dépense enregistrée pour l\'instant';

  @override
  String get addExpense => 'Ajouter une dépense';

  @override
  String get saveExpense => 'Enregistrer la dépense';

  @override
  String get categoryLabel => 'Catégorie';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get optionalNoteHint => 'Note facultative';

  @override
  String get amountDzdLabel => 'Montant (DZD)';

  @override
  String get noNotifications => 'Aucune notification — tout va bien';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get businessProfileTitle => 'Profil de l\'entreprise';

  @override
  String get businessProfileSubtitle =>
      'Modification depuis les paramètres pas encore disponible';

  @override
  String get businessProfileSnack =>
      'Le profil de l\'entreprise est défini lors de l\'inscription — un écran de modification suivra';

  @override
  String get currencyTitle => 'Devise';

  @override
  String get themeTitle => 'Thème';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeSystem => 'Système';

  @override
  String get languageTitle => 'Langue';

  @override
  String get aiSettingsTitle => 'Paramètres IA';

  @override
  String get aiSettingsSubtitle => 'Limites d\'utilisation — Phase 6';

  @override
  String get logoutTitle => 'Déconnexion';

  @override
  String get logoutConfirm => 'Voulez-vous vraiment vous déconnecter ?';

  @override
  String get cancel => 'Annuler';

  @override
  String get setupSaveFailedTitle =>
      'L\'installation n\'a pas pu être enregistrée';

  @override
  String get ok => 'OK';

  @override
  String productsTitleCount(Object count) {
    return 'Produits · $count';
  }

  @override
  String get productsTitle => 'Produits';

  @override
  String get searchProductsHint => 'Rechercher des produits...';

  @override
  String get noProductsFound => 'Aucun produit trouvé';

  @override
  String get qtyOutOfStock => 'Qté : 0 — Rupture de stock';

  @override
  String qtyLowStock(Object qty) {
    return 'Qté : $qty — Stock faible';
  }

  @override
  String qtyOnly(Object qty) {
    return 'Qté : $qty';
  }

  @override
  String get productNotFound => 'Produit introuvable';

  @override
  String get inStockLabel => 'En stock';

  @override
  String get marginLabel => 'Marge';

  @override
  String get pricingLabel => 'Tarification';

  @override
  String purchasePriceValue(Object amount) {
    return 'Achat : $amount DZD';
  }

  @override
  String sellingPriceValue(Object amount) {
    return 'Vente : $amount DZD';
  }

  @override
  String profitPerUnitValue(Object amount) {
    return 'Profit/unité : $amount DZD';
  }

  @override
  String get categoryLabelTitle => 'Catégorie';

  @override
  String get enterValidNumber => 'Saisissez un nombre valide';

  @override
  String get mustBeNonNegative => 'Doit être ≥ 0';

  @override
  String get uncategorized => 'Non catégorisé';

  @override
  String get addProductTitle => 'Ajouter un produit';

  @override
  String get productNameLabel => 'Nom du produit';

  @override
  String get productNameHint => 'ex. Lait entier 1L';

  @override
  String get categoryHint => 'Produits laitiers';

  @override
  String get purchasePriceLabel => 'Prix d\'achat (DZD)';

  @override
  String get sellingPriceLabel => 'Prix de vente (DZD)';

  @override
  String get sellingBelowPurchaseWarning =>
      '⚠ Le prix de vente est inférieur au prix d\'achat';

  @override
  String get quantityLabel => 'Quantité';

  @override
  String get enterValidInteger => 'Saisissez un entier valide ≥ 0';

  @override
  String get saveProduct => 'Enregistrer le produit';

  @override
  String get appointmentsTitle => 'Rendez-vous';

  @override
  String get noAppointmentsScheduled => 'Aucun rendez-vous prévu';

  @override
  String get markCompleted => 'Marquer terminé';

  @override
  String get cancelAppointment => 'Annuler';

  @override
  String appointmentTimeName(Object time, Object name) {
    return '$time — $name';
  }

  @override
  String get newAppointmentTitle => 'Nouveau rendez-vous';

  @override
  String get patientCustomerLabel => 'Patient / Client';

  @override
  String timeLabel(Object time) {
    return 'Heure : $time';
  }

  @override
  String get notesLabel => 'Notes';

  @override
  String get optionalHint => 'Facultatif';

  @override
  String get saveAppointment => 'Enregistrer le rendez-vous';

  @override
  String get reportsTitle => 'Rapports';

  @override
  String get periodDaily => 'Quotidien';

  @override
  String get periodWeekly => 'Hebdomadaire';

  @override
  String get periodMonthly => 'Mensuel';

  @override
  String get periodYearly => 'Annuel';

  @override
  String get exportAsPdf => 'Exporter en PDF';

  @override
  String get exportAsExcel => 'Exporter en Excel';

  @override
  String get exportComingSoon =>
      'L\'export PDF/Excel arrive dans une prochaine mise à jour';

  @override
  String get aiInsightsTitle => 'Analyses IA';

  @override
  String get notEnoughDataForInsights =>
      'Pas encore assez de données pour générer des analyses';

  @override
  String get scanInvoiceTitle => 'Scanner une facture';

  @override
  String get pointCameraAtInvoice => 'Pointez la caméra vers la facture';

  @override
  String get keepInvoiceFlatWellLit =>
      'Gardez la facture à plat et bien éclairée';

  @override
  String get cameraButton => 'Caméra';

  @override
  String get chooseFromGallery => 'Choisir depuis la galerie';

  @override
  String get tryDemoInvoice => '▶ Essayer une facture d\'exemple';

  @override
  String get analyzingInvoice => 'Analyse de la facture...';

  @override
  String get readingTextDetecting =>
      'Lecture du texte, détection des produits et quantités';

  @override
  String get detectedItemsTitle => 'Articles détectés';

  @override
  String qtyValue(Object qty) {
    return 'Qté : $qty';
  }

  @override
  String get reviewAndEdit => 'Vérifier et modifier';

  @override
  String get reviewItemsTitle => 'Vérifier les articles';

  @override
  String get productNameFieldLabel => 'Nom du produit';

  @override
  String get quantityFieldLabel => 'Quantité';

  @override
  String get purchasePriceFieldLabel => 'Prix d\'achat';

  @override
  String get confirmAddToInventory => 'Confirmer et ajouter à l\'inventaire';

  @override
  String productsAddedToInventory(Object count) {
    return '$count produit(s) ajouté(s) à l\'inventaire';
  }

  @override
  String get noProductsLoadedYet =>
      'Aucun produit chargé pour l\'instant — vérifiez votre connexion et réessayez';

  @override
  String onlyNInStock(Object qty, Object name) {
    return 'Seulement $qty en stock pour $name';
  }

  @override
  String outOfStockFor(Object name) {
    return '$name est en rupture de stock';
  }

  @override
  String get addAtLeastOneProduct => 'Ajoutez au moins un produit au panier';

  @override
  String get saleRecordedSuccessfully => 'Vente enregistrée avec succès';

  @override
  String couldNotCompleteSale(Object error) {
    return 'Impossible de finaliser la vente : $error';
  }

  @override
  String get newSaleTitle => 'Nouvelle vente';

  @override
  String get searchProductOrScan =>
      'Rechercher un produit ou scanner un code-barres';

  @override
  String get scanInvoiceChooserTitle => 'Quelle facture voulez-vous scanner ?';

  @override
  String get scanSalesInvoiceOption => 'Facture de vente';

  @override
  String get scanSalesInvoiceSubtitle =>
      'Enregistrer une vente à partir d\'un reçu client';

  @override
  String get scanStockInvoiceOption => 'Facture de stock';

  @override
  String get scanStockInvoiceSubtitle =>
      'Ajouter des articles achetés à l\'inventaire';

  @override
  String get scanBarcodeTooltip => 'Scanner le code-barres';

  @override
  String get barcodeScannerTitle => 'Scanner un code-barres';

  @override
  String get barcodeScannerHint => 'Alignez le code-barres dans le cadre';

  @override
  String get enterCodeManually => 'Saisir le code manuellement';

  @override
  String get manualBarcodeEntryTitle => 'Saisir le code-barres';

  @override
  String barcodeNotFoundMessage(Object code) {
    return 'Aucun produit ne correspond au code $code';
  }

  @override
  String get addAsNewProductAction => 'Ajouter comme nouveau produit';

  @override
  String scannedProductAddedToCart(Object name) {
    return '$name ajouté au panier';
  }

  @override
  String get matchProductLabel => 'Produit correspondant';

  @override
  String get selectProductHint => 'Sélectionner un produit';

  @override
  String get salesInvoiceReviewTitle => 'Vérifier les articles vendus';

  @override
  String get confirmRecordSale => 'Confirmer et enregistrer la vente';

  @override
  String get saleRecordedFromScan =>
      'Vente enregistrée à partir de la facture scannée';

  @override
  String get pleaseMatchAllItems =>
      'Associez chaque article à un produit avant de continuer';

  @override
  String get cameraPermissionRequired =>
      'L\'autorisation de la caméra est requise pour scanner';

  @override
  String get noMatchFound =>
      'Aucune correspondance — sélectionnez manuellement';

  @override
  String get unitPriceLabel => 'Prix unitaire';

  @override
  String get removeItemLabel => 'Supprimer';

  @override
  String get barcodeFieldLabel => 'Code-barres (optionnel)';

  @override
  String get barcodeFieldHint => 'Scanner ou saisir manuellement';

  @override
  String get cartEmpty => 'Le panier est vide — ajoutez un produit ci-dessus';

  @override
  String cartLineLabel(Object name, Object qty) {
    return '$name × $qty';
  }

  @override
  String get discountDzdLabel => 'Remise (DZD)';

  @override
  String get confirmSaleButton => 'Confirmer la vente';

  @override
  String get searchProductDots => 'Rechercher un produit...';

  @override
  String get outOfStockLabel => 'Rupture de stock';
}
