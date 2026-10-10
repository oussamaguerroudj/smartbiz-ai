import 'package:flutter/material.dart';

class DesktopLocalizations {
  final Locale locale;

  DesktopLocalizations(this.locale);

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('fr'),
    Locale('ar'),
  ];

  static bool isRtl(Locale loc) => loc.languageCode == 'ar';

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Modiri AI Desktop',
      'dashboard': 'Dashboard',
      'pos': 'POS & Sales',
      'inventory': 'Inventory',
      'invoices': 'Invoices',
      'reports': 'Reports',
      'settings': 'Settings',
      'login': 'Sign In',
      'register': 'Sign Up',
      'email': 'Email Address',
      'password': 'Password',
      'company': 'Company Name',
      'search': 'Search (Ctrl+K)...',
      'new_sale': 'New Sale (Ctrl+N)',
      'cart': 'Active Cart',
      'total': 'Total',
      'subtotal': 'Subtotal',
      'discount': 'Discount',
      'complete_sale': 'Complete Sale',
      'print': 'Print (Ctrl+P)',
      'daily_revenue': 'Daily Revenue',
      'gross_profit': 'Gross Profit',
      'net_profit': 'Net Profit',
      'low_stock': 'Low Stock Alert',
      'items_count': 'Items',
      'offline_mode': 'Offline Mode',
      'online_mode': 'Connected',
      'logout': 'Sign Out',
      'save': 'Save Changes',
      'api_url': 'Backend API Endpoint',
      'language': 'Language',
    },
    'fr': {
      'app_title': 'Modiri AI Desktop',
      'dashboard': 'Tableau de bord',
      'pos': 'Caisse & Ventes',
      'inventory': 'Inventaire',
      'invoices': 'Factures',
      'reports': 'Rapports',
      'settings': 'Paramètres',
      'login': 'Se connecter',
      'register': "S'inscrire",
      'email': 'Adresse email',
      'password': 'Mot de passe',
      'company': "Nom de l'entreprise",
      'search': 'Rechercher (Ctrl+K)...',
      'new_sale': 'Nouvelle Vente (Ctrl+N)',
      'cart': 'Panier Actif',
      'total': 'Total',
      'subtotal': 'Sous-total',
      'discount': 'Remise',
      'complete_sale': 'Valider la vente',
      'print': 'Imprimer (Ctrl+P)',
      'daily_revenue': 'Revenu Journalier',
      'gross_profit': 'Bénéfice Brut',
      'net_profit': 'Bénéfice Net',
      'low_stock': 'Alerte Stock Bas',
      'items_count': 'Articles',
      'offline_mode': 'Mode Hors Ligne',
      'online_mode': 'Connecté',
      'logout': 'Se déconnecter',
      'save': 'Enregistrer',
      'api_url': 'Endpoint API Serveur',
      'language': 'Langue',
    },
    'ar': {
      'app_title': 'مديري ذكاء اصطناعي للكمبيوتر',
      'dashboard': 'لوحة التحكم',
      'pos': 'نقطة البيع والمبيعات',
      'inventory': 'المخزون والمنتجات',
      'invoices': 'الفواتير',
      'reports': 'التقارير المالية',
      'settings': 'الإعدادات',
      'login': 'تسجيل الدخول',
      'register': 'إنشاء حساب جديد',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'company': 'اسم الشركة أو النشاط',
      'search': 'بحث سريع (Ctrl+K)...',
      'new_sale': 'عملية بيع جديدة (Ctrl+N)',
      'cart': 'السلة الحالية',
      'total': 'المجموع الكلي',
      'subtotal': 'المجموع الفرعي',
      'discount': 'الخصم',
      'complete_sale': 'إتمام البيع',
      'print': 'طباعة (Ctrl+P)',
      'daily_revenue': 'الإيراد اليومي',
      'gross_profit': 'إجمالي الربح',
      'net_profit': 'صافي الربح',
      'low_stock': 'تنبيه نقص المخزون',
      'items_count': 'عناصر',
      'offline_mode': 'وضع عدم الاتصال',
      'online_mode': 'متصل بالنظام',
      'logout': 'تسجيل الخروج',
      'save': 'حفظ التعديلات',
      'api_url': 'رابط خادم النظام (API)',
      'language': 'اللغة',
    },
  };

  String tr(String key) {
    final lang = locale.languageCode;
    return _localizedValues[lang]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }
}
