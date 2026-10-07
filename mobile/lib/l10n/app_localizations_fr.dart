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
  String get businessTypeGrocery => 'Marché / Magasin';

  @override
  String get businessTypeGroceryDesc =>
      'Supermarché, mini-marché, épicerie, supérette';

  @override
  String get businessTypePharmacy => 'Pharmacie';

  @override
  String get businessTypePharmacyDesc => 'Stock, alertes de péremption';

  @override
  String get businessTypeClinic => 'Clinique / Médical';

  @override
  String get businessTypeClinicDesc =>
      'Patients, rendez-vous — médical et dentaire';

  @override
  String get businessTypeRestaurant => 'Restaurant / Café';

  @override
  String get businessTypeRestaurantDesc =>
      'Menu, commandes, tables — restaurants et cafés';

  @override
  String get businessTypeCompany => 'Entreprise / Société';

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
  String get baseSalaryLabel => 'Salaire de base';

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
      'Gérer les informations personnelles et de l\'entreprise';

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
  String get periodDaily => 'Journalière';

  @override
  String get periodWeekly => 'Hebdomadaire';

  @override
  String get periodMonthly => 'Mensuelle';

  @override
  String get periodYearly => 'Annuelle';

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
  String get salePriceFieldLabel => 'Prix de vente';

  @override
  String get salePriceRequired =>
      'Veuillez saisir un prix de vente valide pour tous les produits';

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
  String get noItemsDetected =>
      'Aucun article détecté sur cette photo — réessayez avec un meilleur éclairage.';

  @override
  String get expensePeriodTypeLabel => 'Type de période';

  @override
  String get periodOneTime => 'Ponctuelle';

  @override
  String get periodCustom => 'Personnalisée';

  @override
  String get periodStartLabel => 'Du';

  @override
  String get periodEndLabel => 'Au';

  @override
  String expenseCoversDays(Object days) {
    return 'Couvre $days jour(s)';
  }

  @override
  String get selectPeriodEndDate =>
      'Veuillez choisir une date de fin pour cette période personnalisée';

  @override
  String get selectCustomerFirst => 'Veuillez sélectionner un client d\'abord';

  @override
  String get noCustomersYet =>
      'Aucun client pour le moment — ajoutez-en un d\'abord';

  @override
  String get amountExceedsTotal =>
      'Le montant à payer ne peut pas dépasser le total';

  @override
  String get creditSaleTitle => 'Nouvelle vente à crédit';

  @override
  String get selectCustomerHint => 'Sélectionner un client';

  @override
  String get amountToPayNowLabel => 'Montant à payer maintenant (DZD)';

  @override
  String get remainingCreditLabel => 'Crédit restant';

  @override
  String get confirmCreditSaleButton => 'Confirmer la vente à crédit';

  @override
  String get creditSaleRecorded => 'Vente à crédit enregistrée';

  @override
  String get creditPageTitle => 'Crédit';

  @override
  String get newCreditSaleAction => 'Nouvelle vente à crédit';

  @override
  String get customersWithCreditTitle => 'Clients avec crédit en cours';

  @override
  String get noOutstandingCredit =>
      'Aucun client ne doit d\'argent actuellement';

  @override
  String get totalCreditLabel => 'Crédit total';

  @override
  String get totalPaidLabel => 'Payé';

  @override
  String get noOutstandingBalanceForCustomer =>
      'Ce client n\'a aucun solde impayé';

  @override
  String get recordPaymentTitle => 'Enregistrer un paiement';

  @override
  String currentBalanceHelper(Object balance) {
    return 'Solde actuel : $balance DZD';
  }

  @override
  String get paymentRecorded => 'Paiement enregistré';

  @override
  String get noTransactionsYet => 'Aucune transaction pour le moment';

  @override
  String get creditPurchaseLabel => 'Achat à crédit';

  @override
  String get paymentLabel => 'Paiement';

  @override
  String balanceAfterLabel(Object balance) {
    return 'Solde après : $balance DZD';
  }

  @override
  String get clinicDashboardTitle => 'Tableau de bord clinique';

  @override
  String get patientsTodayLabel => 'Patients aujourd\'hui';

  @override
  String get appointmentsTodayLabel => 'Rendez-vous aujourd\'hui';

  @override
  String get waitingLabel => 'En attente';

  @override
  String get completedTodayLabel => 'Terminés aujourd\'hui';

  @override
  String get noShowTodayLabel => 'Absences aujourd\'hui';

  @override
  String get newPatientsTodayLabel => 'Nouveaux patients aujourd\'hui';

  @override
  String get doctorsLabel => 'Médecins';

  @override
  String get clinicQueueTitle => 'Salle d\'attente';

  @override
  String get callNextPatientButton => 'Appeler le patient suivant';

  @override
  String nextPatientLabel(Object name) {
    return 'Patient suivant : $name';
  }

  @override
  String get noOneWaitingMessage => 'Personne n\'attend actuellement';

  @override
  String get completeConsultationButton => 'Terminer la consultation';

  @override
  String get clinicPatientsTitle => 'Patients';

  @override
  String get addPatientTitle => 'Ajouter un patient';

  @override
  String get fullNameLabel => 'Nom complet';

  @override
  String get genderLabel => 'Genre';

  @override
  String get dateOfBirthLabel => 'Date de naissance';

  @override
  String get savePatient => 'Enregistrer le patient';

  @override
  String get patientProfileTitle => 'Profil du patient';

  @override
  String get visitHistoryTitle => 'Historique des visites';

  @override
  String get noVisitsYetMessage => 'Aucune visite enregistrée pour le moment';

  @override
  String get diagnosisLabel => 'Diagnostic';

  @override
  String get treatmentLabel => 'Traitement';

  @override
  String get prescriptionLabel => 'Ordonnance';

  @override
  String get followUpDateLabel => 'Date de suivi';

  @override
  String get addToQueueAction => 'Ajouter à la file d\'attente';

  @override
  String get selectPatientTitle => 'Sélectionner un patient';

  @override
  String get searchPatientsHint => 'Rechercher des patients...';

  @override
  String get noPatientsFoundMessage => 'Aucun patient trouvé';

  @override
  String get delete => 'Supprimer';

  @override
  String get documentsTitle => 'Documents médicaux';

  @override
  String get addDocumentAction => 'Ajouter un document';

  @override
  String get documentNameLabel => 'Nom du document';

  @override
  String get documentTypeLabel => 'Type de document';

  @override
  String get fileUrlLabel => 'URL du fichier';

  @override
  String get noDocumentsYetMessage => 'Aucun document pour le moment';

  @override
  String get confirmDeleteDocumentMessage => 'Supprimer ce document ?';

  @override
  String get documentDeletedMessage => 'Document supprimé';

  @override
  String get documentAddedMessage => 'Document ajouté';

  @override
  String get prescriptionsTitle => 'Ordonnances';

  @override
  String get newPrescriptionAction => 'Nouvelle ordonnance';

  @override
  String get noPrescriptionsYetMessage => 'Aucune ordonnance pour le moment';

  @override
  String get medicationNameLabel => 'Nom du médicament';

  @override
  String get dosageLabel => 'Posologie';

  @override
  String get frequencyLabel => 'Fréquence';

  @override
  String get durationLabel => 'Durée';

  @override
  String get instructionsLabel => 'Instructions';

  @override
  String get addMedicationAction => 'Ajouter un médicament';

  @override
  String get savePrescriptionAction => 'Enregistrer l\'ordonnance';

  @override
  String get prescriptionSavedMessage => 'Ordonnance enregistrée';

  @override
  String get prescriptionNumberLabel => 'N° d\'ordonnance';

  @override
  String get medicationRequiredMessage => 'Au moins un médicament est requis';

  @override
  String get patientAddedMessage => 'Patient ajouté';

  @override
  String get queueEmptyMessage => 'La salle d\'attente est vide';

  @override
  String get consultationPriceLabel => 'Prix de la consultation';

  @override
  String get amountPaidLabel => 'Montant payé';

  @override
  String get markFullyPaidLabel => 'Marquer comme payé intégralement';

  @override
  String get remainingLabel => 'Reste à payer';

  @override
  String get invoiceTitle => 'Facture';

  @override
  String get paymentStatusLabel => 'Statut de paiement';

  @override
  String get orderDetailsTitle => 'Détails de la commande';

  @override
  String get paidAmountShortLabel => 'Payé';

  @override
  String get updateStatusLabel => 'Mettre à jour le statut';

  @override
  String get restaurantRecordPaymentAction => 'Enregistrer le paiement';

  @override
  String get paymentRecordedMessage => 'Paiement enregistré';

  @override
  String get enterValidAmountMessage => 'Entrez un montant valide';

  @override
  String get confirmAction => 'Confirmer';

  @override
  String get addInventoryItemTitle => 'Ajouter un article d\'inventaire';

  @override
  String get applyAction => 'Appliquer';

  @override
  String get minStockLabel => 'Stock min.';

  @override
  String get noInventoryItemsMessage => 'Aucun article en inventaire';

  @override
  String get openingQuantityLabel => 'Quantité initiale';

  @override
  String get removeAction => 'Supprimer';

  @override
  String get searchInventoryHint => 'Rechercher dans l\'inventaire...';

  @override
  String get supplierLabel => 'Fournisseur';

  @override
  String get unitLabel => 'Unité';

  @override
  String get lowStockLabel => 'Stock faible';

  @override
  String get enterNonZeroAmountMessage => 'Entrez un montant non nul';

  @override
  String get manualAdjustmentLabel => 'Ajustement manuel';

  @override
  String get inventoryTitle => 'Inventaire';

  @override
  String get saveRecipeAction => 'Enregistrer la recette';

  @override
  String get addAction => 'Ajouter';

  @override
  String get ordersTitle => 'Commandes';

  @override
  String get noActiveOrdersMessage => 'Aucune commande active pour le moment';

  @override
  String get moveToNextStageTooltip => 'Passer à l\'étape suivante';

  @override
  String get cancelOrderTooltip => 'Annuler la commande';

  @override
  String get takeawayLabel => 'À emporter';

  @override
  String get newOrderTitle => 'Nouvelle commande';

  @override
  String get tableOptionalLabel => 'Table (facultatif — à emporter si vide)';

  @override
  String get takeawayNoTableOption => 'À emporter / sans table';

  @override
  String get noMenuItemsYetMessage =>
      'Aucun article au menu — ajoutez-en depuis l\'écran Menu';

  @override
  String get addAtLeastOneItemMessage => 'Ajoutez au moins un article';

  @override
  String get orderCreatedMessage => 'Commande créée';

  @override
  String get createOrderAction => 'Créer la commande';

  @override
  String get tablesTitle => 'Tables';

  @override
  String get addTableTitle => 'Ajouter une table';

  @override
  String get tableNameFieldLabel => 'Nom / numéro de table';

  @override
  String get seatsLabel => 'Places';

  @override
  String get noTablesYetMessage => 'Aucune table pour le moment';

  @override
  String get saveAction => 'Enregistrer';

  @override
  String get reservationsTitle => 'Réservations';

  @override
  String get newReservationTitle => 'Nouvelle réservation';

  @override
  String get customerNameLabel => 'Nom du client';

  @override
  String get partySizeLabel => 'Nombre de convives';

  @override
  String get noReservationsYetMessage => 'Aucune réservation pour le moment';

  @override
  String get seatAction => 'Installer';

  @override
  String get menuTitle => 'Menu';

  @override
  String get addMenuItemTitle => 'Ajouter un plat';

  @override
  String get dishNameLabel => 'Nom du plat';

  @override
  String get categoryOptionalLabel => 'Catégorie (facultatif)';

  @override
  String get priceDzdLabel => 'Prix (DZD)';

  @override
  String get enterValidPriceMessage => 'Entrez un prix valide';

  @override
  String get recipeIngredientsTooltip => 'Recette (ingrédients)';

  @override
  String get noShowLabel => 'Absence';

  @override
  String get dateTimeLabel => 'Date et heure';

  @override
  String get guestsLabel => 'convives';

  @override
  String adjustItemTitle(Object itemName) {
    return 'Ajuster $itemName';
  }

  @override
  String adjustQuantityHint(Object unit) {
    return 'Changement ($unit) — négatif pour retirer';
  }

  @override
  String get todayRevenueLabel => 'Recette du jour';

  @override
  String get todayProfitLabel => 'Bénéfice du jour';

  @override
  String get outstandingPaymentsLabel => 'Paiements en attente';

  @override
  String get paymentStatusPaidLabel => 'Payé';

  @override
  String get paymentStatusPartialLabel => 'Payé partiellement';

  @override
  String get paymentStatusUnpaidLabel => 'Non payé';

  @override
  String get paymentStatusRefundedLabel => 'Remboursé';

  @override
  String get clinicRecordPaymentAction => 'Enregistrer un paiement';

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

  @override
  String get storeDashboardTitle => 'Tableau de bord du magasin';

  @override
  String get pharmacyDashboardTitle => 'Tableau de bord de la pharmacie';

  @override
  String get customerDebtLabel => 'Dette clients';

  @override
  String get stockValueLabel => 'Valeur du stock';

  @override
  String get expiringSoonLabel => 'Expire bientôt';

  @override
  String get inventoryValueLabel => 'Valeur de l\'inventaire';

  @override
  String get kpiSubtitleDzdToday => 'DZD aujourd\'hui';

  @override
  String get kpiSubtitleNetToday => 'Net, aujourd\'hui';

  @override
  String get transactionsLabel => 'Transactions';

  @override
  String get stockAlertsTitle => 'Alertes de stock';

  @override
  String get noStockAlertsMessage => 'Aucune alerte de stock pour le moment';

  @override
  String get noStockOrExpiryAlertsMessage =>
      'Aucune alerte de stock ou d\'expiration pour le moment';

  @override
  String get customerDebtTitle => 'Dette clients';

  @override
  String get noOutstandingDebtMessage => 'Aucune dette client en cours';

  @override
  String get stockByCategoryTitle => 'Stock par catégorie';

  @override
  String get noProductsYetMessage => 'Aucun produit pour le moment';

  @override
  String get expirationDateLabel => 'Date d\'expiration';

  @override
  String get selectDateHint => 'Sélectionner une date';

  @override
  String get clearDateAction => 'Effacer';

  @override
  String get sizeLabel => 'Taille';

  @override
  String get colorLabel => 'Couleur';

  @override
  String get brandLabel => 'Marque';

  @override
  String get editProductTitle => 'Modifier le produit';

  @override
  String get editAction => 'Modifier';

  @override
  String get saveChangesAction => 'Enregistrer les modifications';

  @override
  String get productUpdatedMessage => 'Produit mis à jour';

  @override
  String get goodDay => 'Bonne journée';

  @override
  String get companyDashboardTitle => 'Tableau de bord entreprise';

  @override
  String get openProjectsLabel => 'Projets en cours';

  @override
  String get dzdThisMonthLabel => 'DZD ce mois-ci';

  @override
  String get thisMonthLabel => 'Ce mois-ci';

  @override
  String get netProfitLabel => 'Bénéfice net';

  @override
  String get salariesLabel => 'Salaires';

  @override
  String todayRevenueProfit(Object revenue, Object profit) {
    return 'Aujourd\'hui : $revenue revenu · $profit bénéfice';
  }

  @override
  String get projectsTitle => 'Projets';

  @override
  String get noOpenProjectsMessage => 'Aucun projet en cours';

  @override
  String overdueCount(Object count) {
    return '$count en retard';
  }

  @override
  String get unpaidInvoicesTitle => 'Factures impayées';

  @override
  String get noUnpaidInvoicesMessage => 'Aucune facture impayée';

  @override
  String clientCreditBalancesMessage(Object amount) {
    return 'Soldes créditeurs clients : $amount';
  }

  @override
  String get noProjectsYetMessage => 'Aucun projet pour l\'instant';

  @override
  String get dueDateBeforeStartDateError =>
      'La date d\'échéance ne peut pas être antérieure à la date de début';

  @override
  String get newProjectTitle => 'Nouveau projet';

  @override
  String get projectNameLabel => 'Nom du projet';

  @override
  String get clientOptionalLabel => 'Client (facultatif)';

  @override
  String get noClientOption => 'Aucun client';

  @override
  String get budgetDzdOptionalLabel => 'Budget (DZD, facultatif)';

  @override
  String get descriptionOptionalLabel => 'Description (facultatif)';

  @override
  String get startDateLabel => 'Date de début';

  @override
  String get dueDateLabel => 'Date d\'échéance';

  @override
  String get restaurantDashboardTitle => 'Tableau de bord restaurant';

  @override
  String get tablesOccupiedLabel => 'Tables occupées';

  @override
  String get reservationsTodayLabel => 'Réservations aujourd\'hui';

  @override
  String get todaysOrdersLabel => 'Commandes d\'aujourd\'hui';

  @override
  String get activeOrdersLabel => 'Commandes actives';

  @override
  String get inProgressLabel => 'En cours';

  @override
  String pendingCount(Object count) {
    return '$count en attente';
  }

  @override
  String preparingCount(Object count) {
    return '$count en préparation';
  }

  @override
  String readyCount(Object count) {
    return '$count prêt(s)';
  }

  @override
  String get clothingProductsTitle => 'Produits de vêtements';

  @override
  String get viewAllAction => 'Tout voir';

  @override
  String get noClothingProductsMessage =>
      'Aucun produit de vêtements ajouté pour l\'instant';

  @override
  String expiresOnLabel(Object date) {
    return 'expire le $date';
  }

  @override
  String deleteConfirmTitle(Object item) {
    return 'Supprimer $item';
  }

  @override
  String deleteConfirmMessage(Object item) {
    return 'Voulez-vous vraiment supprimer cet élément ($item) ?';
  }

  @override
  String get serverSettingsTitle => 'Paramètres du serveur';

  @override
  String get serverBaseUrlLabel => 'URL de base du serveur';

  @override
  String get testConnectionAction => 'Tester la connexion';

  @override
  String get editExpenseTitle => 'Modifier la dépense';

  @override
  String get updateExpenseAction => 'Mettre à jour la dépense';

  @override
  String get editMenuItemTitle => 'Modifier le plat';

  @override
  String recipeTitle(Object name) {
    return 'Recette — $name';
  }

  @override
  String quantityRequiredUnit(Object unit) {
    return 'Quantité requise ($unit)';
  }

  @override
  String enterValidQuantityFor(Object name) {
    return 'Saisissez une quantité valide pour $name';
  }

  @override
  String get noPastOrdersFoundMessage => 'Aucune ancienne commande trouvée';

  @override
  String get deleteMenuItemTitle => 'Supprimer le plat';

  @override
  String get deleteSupplierTitle => 'Supprimer le fournisseur';

  @override
  String get deleteCustomerTitle => 'Supprimer le client';

  @override
  String get deleteEmployeeTitle => 'Supprimer l\'employé';

  @override
  String get deleteExpenseTitle => 'Supprimer la dépense';

  @override
  String get deleteProductTitle => 'Supprimer le produit';

  @override
  String get supplierFallback => 'Fournisseur';

  @override
  String get customerFallback => 'Client';

  @override
  String get expenseFallback => 'Dépense';

  @override
  String get personalProfileTitle => 'Profil personnel';

  @override
  String get saveProfile => 'Enregistrer le profil';

  @override
  String get profileUpdatedSuccess => 'Profil mis à jour avec succès';

  @override
  String errorUpdatingProfile(Object error) {
    return 'Erreur lors de la mise à jour du profil : $error';
  }

  @override
  String get businessInfoTitle => 'Informations de l\'entreprise';

  @override
  String get updateBusinessInfo => 'Mettre à jour les informations';

  @override
  String get businessInfoUpdatedSuccess =>
      'Informations de l\'entreprise mises à jour avec succès';

  @override
  String errorUpdatingBusiness(Object error) {
    return 'Erreur lors de la mise à jour de l\'entreprise : $error';
  }

  @override
  String get changePasswordTitle => 'Changer le mot de passe';

  @override
  String get currentPassword => 'Mot de passe actuel';

  @override
  String get enterCurrentPassword => 'Entrez le mot de passe actuel';

  @override
  String get confirmNewPassword => 'Confirmer le nouveau mot de passe';

  @override
  String get confirmYourNewPassword => 'Confirmez votre nouveau mot de passe';

  @override
  String get updatePasswordAction => 'Mettre à jour le mot de passe';

  @override
  String get passwordChangedSuccess => 'Mot de passe modifié avec succès';

  @override
  String errorChangingPassword(Object error) {
    return 'Erreur lors de la modification du mot de passe : $error';
  }

  @override
  String get dangerZoneTitle => 'Zone dangereuse';

  @override
  String get deleteAccountPermanently => 'Supprimer définitivement le compte';

  @override
  String get deleteAccountWarning =>
      'La suppression de votre compte supprimera définitivement votre profil, vos paramètres, produits, ventes et factures. Cette action est irréversible.';

  @override
  String get enterPasswordToConfirm =>
      'Entrez votre mot de passe pour confirmer';

  @override
  String get deletePermanentlyAction => 'Supprimer définitivement';

  @override
  String accountDeletionFailed(Object error) {
    return 'Échec de la suppression du compte : $error';
  }

  @override
  String failedToPickImage(Object error) {
    return 'Échec de sélection de l\'image : $error';
  }

  @override
  String get businessPhoneLabel => 'Téléphone professionnel';

  @override
  String get businessAddressLabel => 'Adresse professionnelle';

  @override
  String get businessNameRequired => 'Le nom de l\'entreprise est requis';

  @override
  String get reportRevenueLabel => 'Revenus';

  @override
  String get reportExpensesLabel => 'Dépenses';

  @override
  String get reportNetProfitLabel => 'Bénéfice net';

  @override
  String get salesCountLabel => 'Nombre de ventes';

  @override
  String salesCountInPeriod(Object count) {
    return '$count vente(s) sur cette période';
  }

  @override
  String get topProductsTitle => 'Meilleurs produits';

  @override
  String unitsSoldLabel(Object count) {
    return '$count vendu(s)';
  }

  @override
  String get noActivityInPeriod =>
      'Aucune activité enregistrée pour cette période';

  @override
  String get aiActiveSnack => 'Assistant IA et scanner OCR actifs';

  @override
  String get businessTypeRetail => 'Commerce de détail général';

  @override
  String get financialOverview => 'Aperçu Financier';

  @override
  String get revenueBreakdownTitle => 'Détails des Revenus';

  @override
  String get expensesBreakdownTitle => 'Détails des Dépenses';

  @override
  String get operatingExpensesLabel => 'Dépenses d\'exploitation';

  @override
  String get employeeSalariesLabel => 'Salaires des Employés';

  @override
  String get totalExpensesLabel => 'Total des Dépenses';

  @override
  String get profitCalculationTitle => 'Calcul du Bénéfice';

  @override
  String get profitMarginLabel => 'Marge Bénéficiaire';

  @override
  String get netLossLabel => 'Perte Nette';

  @override
  String get activitySummaryTitle => 'Résumé d\'Activité';

  @override
  String get invoicesCountLabel => 'Factures';

  @override
  String get expensesCountLabel => 'Dépenses';

  @override
  String get employeesCountLabel => 'Employés';

  @override
  String get recentTransactionsTitle => 'Transactions Récentes';

  @override
  String get noTransactionsInPeriod => 'Aucune transaction sur cette période';

  @override
  String get coreSalesLabel => 'Ventes Directes';

  @override
  String get creditPaymentsLabel => 'Règlements Crédit';

  @override
  String get categoryBreakdownTitle => 'Dépenses par Catégorie';

  @override
  String get employeeBreakdownTitle => 'Salaires par Employé';

  @override
  String get noEmployeesFound => 'Aucun employé enregistré';

  @override
  String get noExpensesFound => 'Aucune dépense enregistrée';

  @override
  String get profitFormulaExplanation =>
      'Bénéfice Net = Revenus - Total des Dépenses';

  @override
  String get dateRangeLabel => 'Période';

  @override
  String get scanStageUploading => 'Envoi de l\'image de la facture...';

  @override
  String get scanStageOcr => 'Reconnaissance de texte OCR en cours...';

  @override
  String get scanStageExtracting => 'Extraction des produits et des prix...';

  @override
  String get scanStageFinalizing =>
      'Finalisation des articles de la facture...';

  @override
  String get scanTimeoutMessage =>
      'Délai d\'analyse dépassé. Veuillez réessayer ou vérifier la connexion IA.';

  @override
  String get scanCancelledMessage => 'L\'analyse de la facture a été annulée.';

  @override
  String get retryScanAction => 'Réessayer l\'analyse';

  @override
  String get aiServiceDisabledMessage =>
      'Les services IA sont désactivés. Veuillez les activer dans les Paramètres.';

  @override
  String get aiServiceUnavailableMessage =>
      'Le serveur IA est inaccessible. Vérifiez la connexion dans les Paramètres.';

  @override
  String get scanFailedTitle => 'Échec de l\'analyse';

  @override
  String get scanSuccessTitle => 'Facture analysée avec succès';

  @override
  String get cancelScanAction => 'Annuler l\'analyse';

  @override
  String get aiStatusOnline => 'En ligne';

  @override
  String get aiStatusDegraded => 'Dégradé (Modèles manquants)';

  @override
  String get aiStatusOffline => 'Hors ligne';

  @override
  String get aiStatusDisabled => 'Désactivé';

  @override
  String get aiEnabledLabel => 'Activer les fonctionnalités IA';

  @override
  String get aiEnabledDescription =>
      'Utiliser l\'IA locale pour la numérisation des factures, l\'OCR et les analyses';

  @override
  String get aiServerUrlLabel => 'URL du serveur IA';

  @override
  String get aiServerUrlHint => 'ex. http://10.0.2.2:11434/v1';

  @override
  String get aiOcrModelLabel => 'Modèle OCR';

  @override
  String get aiVisionModelLabel => 'Modèle Vision';

  @override
  String get aiChatModelLabel => 'Modèle Assistant / Chat';

  @override
  String get testAiConnectionAction => 'Tester la connexion IA';

  @override
  String get aiConnectionSuccessMessage => 'Connexion au serveur IA réussie';

  @override
  String aiConnectionFailedMessage(Object error) {
    return 'Échec de connexion : $error';
  }

  @override
  String get availableModelsLabel => 'Modèles disponibles sur le serveur';

  @override
  String get missingModelsLabel => 'Modèles manquants';

  @override
  String get saveAiSettingsAction => 'Enregistrer les paramètres IA';

  @override
  String get aiSettingsSavedSuccess => 'Paramètres IA enregistrés avec succès';

  @override
  String get couldNotLoadSalesTrend =>
      'Impossible de charger la tendance des ventes';

  @override
  String get askAboutYourBusiness => 'Posez une question sur votre entreprise';

  @override
  String get aiAnswersComputedLive =>
      'Les réponses sont calculées en direct depuis vos données';

  @override
  String get changeStatusTitle => 'Changer le statut';

  @override
  String get deleteProductTooltip => 'Supprimer le produit';

  @override
  String get projectStatusPlanned => 'Planifié';

  @override
  String get projectStatusInProgress => 'En cours';

  @override
  String get projectStatusOnHold => 'En attente';

  @override
  String get projectStatusCompleted => 'Terminé';

  @override
  String get projectStatusCancelled => 'Annulé';

  @override
  String get projectStatusOverdue => 'En retard';

  @override
  String get globalNetProfitTitle => 'Bénéfice net global';

  @override
  String get allRevenueLabel => 'Tous les revenus';

  @override
  String get allExpensesLabel => 'Toutes les dépenses';

  @override
  String get globalBalanceLabel => 'Solde global';

  @override
  String get selectDate => 'Sélectionner une date';

  @override
  String get selectMonth => 'Sélectionner un mois';

  @override
  String get selectYear => 'Sélectionner une année';

  @override
  String get salaryPeriodLabel => 'Période de salaire';

  @override
  String get paymentDateLabel => 'Date de paiement';

  @override
  String get paySalary => 'Payer le salaire';

  @override
  String get recordSalaryPayment => 'Enregistrer un paiement de salaire';

  @override
  String get duplicateSalaryWarningTitle => 'Salaire déjà payé';

  @override
  String get duplicateSalaryWarningMessage =>
      'Un paiement de salaire pour cet employé pour cette période existe déjà. Êtes-vous sûr de vouloir enregistrer un autre paiement ?';

  @override
  String get monthlyBreakdownTitle => 'Répartition mensuelle';

  @override
  String get noTransactionsForPeriod =>
      'Aucune transaction enregistrée pour cette période';

  @override
  String get salaryExpenseLabel => 'Dépenses salariales';

  @override
  String get otherExpensesLabel => 'Autres dépenses';

  @override
  String get chooseEmployee => 'Choisir un employé';

  @override
  String get salaryPaidSuccess => 'Paiement de salaire enregistré avec succès';

  @override
  String get dailyReportTitle => 'Rapport journalier';

  @override
  String get monthlyReportTitle => 'Rapport mensuel';

  @override
  String get yearlyReportTitle => 'Rapport annuel';

  @override
  String get connectionOnline => 'Connecté';

  @override
  String get connectionOffline =>
      'Hors ligne — Données enregistrées sur cet appareil';

  @override
  String get connectionServerUnavailable =>
      'Serveur indisponible — Mode hors ligne';

  @override
  String syncingPending(Object count) {
    return 'Synchronisation de $count opérations en attente...';
  }

  @override
  String get syncSuccess => 'Toutes les opérations sont synchronisées';

  @override
  String get syncFailed =>
      'Certaines opérations n\'ont pas pu être synchronisées';

  @override
  String get syncNow => 'Synchroniser maintenant';

  @override
  String get pendingOperations => 'Opérations en attente';

  @override
  String get syncedOperations => 'Opérations synchronisées';

  @override
  String get failedOperations => 'Opérations ayant échoué';

  @override
  String get syncDetails => 'Détails de synchronisation';

  @override
  String lastSynced(Object time) {
    return 'Dernière synchro: $time';
  }

  @override
  String get noPendingOperations => 'Aucune opération en attente';

  @override
  String get firstTimeAuthInternetRequired =>
      'Une connexion Internet est requise pour la première authentification du compte.';

  @override
  String get firstTimeRegisterInternetRequired =>
      'Une connexion Internet est requise pour créer un nouveau compte.';

  @override
  String activeClients(Object count) {
    return 'Clients en cours ($count)';
  }

  @override
  String get newClientAction => '+ Nouveau client';

  @override
  String get holdCartAction => 'Mettre en attente';

  @override
  String get resumeCartAction => 'Reprendre';

  @override
  String get clearCartAction => 'Vider le panier';

  @override
  String get cartOnHoldStatus => 'En attente';

  @override
  String cartItemCount(Object count) {
    return '$count articles';
  }

  @override
  String get openCartsTitle => 'Paniers ouverts';

  @override
  String get newCartAction => '+ Nouveau panier';

  @override
  String get noOpenCarts =>
      'Aucun panier ouvert — appuyez sur + pour commencer';

  @override
  String cartLabel(Object index) {
    return 'Panier $index';
  }

  @override
  String cartProductCount(Object count) {
    return '$count produits';
  }

  @override
  String get deleteCartTooltip => 'Supprimer le panier';

  @override
  String get deleteCartTitle => 'Supprimer le panier';

  @override
  String deleteCartConfirm(Object name) {
    return 'Supprimer le panier de $name ? Cette action est irréversible.';
  }

  @override
  String orderNumberLabel(Object number) {
    return 'COMMANDE #$number';
  }

  @override
  String get dineInOption => 'Sur place';

  @override
  String get takeawayOption => 'À emporter';

  @override
  String get deliveryOption => 'Livraison';

  @override
  String get paymentStatusPaidBadge => 'PAYÉ';

  @override
  String get paymentStatusUnpaidBadge => 'IMPAYÉ';

  @override
  String get paymentStatusPartiallyPaidBadge => 'PARTIELLEMENT PAYÉ';

  @override
  String get orderNotReadyMessage => 'La commande n\'est pas encore prête.';

  @override
  String get paymentRequiredMessage =>
      'Le paiement est requis avant de terminer la commande.';

  @override
  String get completeOrderAction => 'Terminer la commande';

  @override
  String get payNowAction => 'Payer maintenant';

  @override
  String get payFullAmountAction => 'Payer la totalité';

  @override
  String get partialPaymentAction => 'Paiement partiel';

  @override
  String get remainingAmountLabel => 'Reste à payer';

  @override
  String get paymentCompletedTitle => 'Paiement';

  @override
  String get tableStatusAvailable => 'DISPONIBLE';

  @override
  String get tableStatusOccupied => 'OCCUPÉE';

  @override
  String get tableStatusOrderReady => 'COMMANDE PRÊTE';

  @override
  String get tableStatusPaymentPending => 'EN ATTENTE DE PAIEMENT';

  @override
  String get tableStatusCompleted => 'TERMINÉE';

  @override
  String get switchOrderAction => 'Changer de commande';

  @override
  String elapsedMinutes(Object minutes) {
    return 'Il y a $minutes min';
  }

  @override
  String get elapsedJustNow => 'À l\'instant';

  @override
  String get preparationStatusLabel => 'Préparation';

  @override
  String get orderTypeLabel => 'Type de commande';

  @override
  String get anonymousWalkInCustomer => 'Client de passage';

  @override
  String get dashboardPagesTitle => 'Pages';

  @override
  String get allPagesTitle => 'Toutes les pages';

  @override
  String get allPagesSubtitle => 'Toutes les pages et modules de gestion';

  @override
  String get extraPagesTitle => 'Pages supplémentaires';

  @override
  String get salesPosTitle => 'Point de vente';

  @override
  String get cashPaymentMethod => 'Espèces';

  @override
  String get cardPaymentMethod => 'Carte bancaire';

  @override
  String get editItemTooltip => 'Modifier l\'article';

  @override
  String get previousDayTooltip => 'Jour précédent';

  @override
  String get nextDayTooltip => 'Jour suivant';

  @override
  String get previousMonthTooltip => 'Mois précédent';

  @override
  String get nextMonthTooltip => 'Mois suivant';

  @override
  String get previousYearTooltip => 'Année précédente';

  @override
  String get nextYearTooltip => 'Année suivante';

  @override
  String customerHasUnpaidDebt(Object amount) {
    return 'Impossible de supprimer un client avec une dette impayée ($amount DZD)';
  }

  @override
  String customerDeletedSuccess(Object name) {
    return 'Client « $name » supprimé';
  }

  @override
  String employeeDeletedSuccess(Object name) {
    return 'Employé « $name » supprimé';
  }

  @override
  String supplierDeletedSuccess(Object name) {
    return 'Fournisseur « $name » supprimé';
  }

  @override
  String get invalidBarcodeChecksum =>
      'Somme de contrôle du code-barres invalide (corrompu ou illisible)';

  @override
  String get invalidBarcodeFormat => 'Format de code-barres non valide';

  @override
  String get configureServerUrlHint =>
      'Configurer l\'adresse de l\'API backend :';

  @override
  String get appTagline => 'Gestion d\'entreprise propulsée par l\'IA';

  @override
  String get clientPhoneNumberLabel => 'Numéro de téléphone du client';

  @override
  String get clientPhoneRequired =>
      'Le numéro de téléphone est obligatoire pour la livraison';

  @override
  String get invalidPhoneNumber => 'Format de numéro de téléphone invalide';

  @override
  String get deliveryAddressLabel => 'Adresse de livraison';

  @override
  String get deliveryAddressHint => 'Rue, bâtiment, étage, appartement...';

  @override
  String get deliveryAddressRequired =>
      'L\'adresse de livraison est obligatoire';

  @override
  String get noTableSelected => 'Aucune table (facultatif)';

  @override
  String get selectRestaurantTable => 'Table de restaurant (facultatif)';

  @override
  String assignedTableLabel(Object name) {
    return 'Table : $name';
  }

  @override
  String get editAppointmentTitle => 'Modifier le rendez-vous';

  @override
  String get updateAppointmentAction => 'Mettre à jour le rendez-vous';

  @override
  String get editReservationTitle => 'Modifier la réservation';

  @override
  String get updateReservationAction => 'Mettre à jour la réservation';

  @override
  String get callClientTooltip => 'Appeler le client';

  @override
  String get copyPhoneTooltip => 'Copier le numéro de téléphone';

  @override
  String get phoneCopiedMessage =>
      'Numéro de téléphone copié dans le presse-papier';

  @override
  String get selectExistingCustomerHint => 'Ou sélectionner un client existant';

  @override
  String get editOrderTitle => 'Modifier la commande';

  @override
  String get updateOrderAction => 'Mettre à jour la commande';

  @override
  String get orderUpdatedMessage => 'Commande mise à jour avec succès';

  @override
  String get moreSectionOperations => 'Opérations et commerce';

  @override
  String get moreSectionSpecialized => 'Activité spécialisée';

  @override
  String get moreSectionIntelligence => 'IA et intelligence';

  @override
  String get moreSectionSystem => 'Système et compte';
}
