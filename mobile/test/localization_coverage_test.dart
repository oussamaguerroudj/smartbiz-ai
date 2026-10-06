import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/l10n/app_localizations.dart';

void main() {
  group('Localization Coverage & Multi-Language Tests', () {
    test('English translations are complete and non-empty', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(l10n.scanStageUploading, isNotEmpty);
      expect(l10n.scanStageOcr, isNotEmpty);
      expect(l10n.scanStageExtracting, isNotEmpty);
      expect(l10n.scanStageFinalizing, isNotEmpty);
      expect(l10n.scanTimeoutMessage, isNotEmpty);
      expect(l10n.retryScanAction, isNotEmpty);
      expect(l10n.cancelScanAction, isNotEmpty);
      expect(l10n.aiServiceDisabledMessage, isNotEmpty);
      expect(l10n.aiStatusOnline, isNotEmpty);
      expect(l10n.aiStatusDegraded, isNotEmpty);
      expect(l10n.aiStatusOffline, isNotEmpty);
      expect(l10n.aiStatusDisabled, isNotEmpty);
      expect(l10n.couldNotLoadSalesTrend, isNotEmpty);
      expect(l10n.askAboutYourBusiness, isNotEmpty);
      expect(l10n.aiAnswersComputedLive, isNotEmpty);
      expect(l10n.projectStatusPlanned, 'Planned');
      expect(l10n.projectStatusInProgress, 'In progress');

      // Newly added production keys
      expect(l10n.cashPaymentMethod, 'Cash');
      expect(l10n.cardPaymentMethod, 'Card');
      expect(l10n.editItemTooltip, 'Edit item');
      expect(l10n.previousDayTooltip, 'Previous Day');
      expect(l10n.nextDayTooltip, 'Next Day');
      expect(l10n.previousMonthTooltip, 'Previous Month');
      expect(l10n.nextMonthTooltip, 'Next Month');
      expect(l10n.previousYearTooltip, 'Previous Year');
      expect(l10n.nextYearTooltip, 'Next Year');
      expect(l10n.customerHasUnpaidDebt('1000'), 'Cannot delete customer with unpaid debt (1000 DZD)');
      expect(l10n.customerDeletedSuccess('Alice'), 'Customer "Alice" deleted');
      expect(l10n.employeeDeletedSuccess('Bob'), 'Employee "Bob" deleted');
      expect(l10n.supplierDeletedSuccess('Vendor'), 'Supplier "Vendor" deleted');
      expect(l10n.invalidBarcodeChecksum, contains('checksum'));
      expect(l10n.invalidBarcodeFormat, contains('format'));
      expect(l10n.configureServerUrlHint, contains('Configure'));
      expect(l10n.appTagline, 'AI-Powered Business Management');
    });

    test('French translations are complete and non-empty', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('fr'));
      expect(l10n.scanStageUploading, isNotEmpty);
      expect(l10n.scanStageOcr, isNotEmpty);
      expect(l10n.scanStageExtracting, isNotEmpty);
      expect(l10n.scanStageFinalizing, isNotEmpty);
      expect(l10n.scanTimeoutMessage, isNotEmpty);
      expect(l10n.retryScanAction, isNotEmpty);
      expect(l10n.cancelScanAction, isNotEmpty);
      expect(l10n.aiServiceDisabledMessage, isNotEmpty);
      expect(l10n.aiStatusOnline, 'En ligne');
      expect(l10n.aiStatusOffline, 'Hors ligne');
      expect(l10n.couldNotLoadSalesTrend, isNotEmpty);
      expect(l10n.projectStatusPlanned, 'Planifié');
      expect(l10n.projectStatusInProgress, 'En cours');

      // Newly added production keys
      expect(l10n.cashPaymentMethod, 'Espèces');
      expect(l10n.cardPaymentMethod, 'Carte bancaire');
      expect(l10n.editItemTooltip, "Modifier l'article");
      expect(l10n.previousDayTooltip, 'Jour précédent');
      expect(l10n.nextDayTooltip, 'Jour suivant');
      expect(l10n.customerHasUnpaidDebt('1000'), contains('dette impayée'));
      expect(l10n.customerDeletedSuccess('Alice'), contains('supprimé'));
      expect(l10n.employeeDeletedSuccess('Bob'), contains('supprimé'));
      expect(l10n.supplierDeletedSuccess('Vendor'), contains('supprimé'));
      expect(l10n.invalidBarcodeChecksum, contains('contrôle'));
      expect(l10n.appTagline, "Gestion d'entreprise propulsée par l'IA");
    });

    test('Arabic translations are complete, non-empty, and RTL compliant', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      expect(l10n.scanStageUploading, isNotEmpty);
      expect(l10n.scanStageOcr, isNotEmpty);
      expect(l10n.scanStageExtracting, isNotEmpty);
      expect(l10n.scanStageFinalizing, isNotEmpty);
      expect(l10n.scanTimeoutMessage, isNotEmpty);
      expect(l10n.retryScanAction, 'إعادة المسح');
      expect(l10n.cancelScanAction, 'إلغاء المسح');
      expect(l10n.aiServiceDisabledMessage, isNotEmpty);
      expect(l10n.aiStatusOnline, 'متصل');
      expect(l10n.aiStatusOffline, 'غير متصل');
      expect(l10n.couldNotLoadSalesTrend, isNotEmpty);
      expect(l10n.projectStatusPlanned, 'مخطط');
      expect(l10n.projectStatusInProgress, 'قيد التنفيذ');

      // Newly added production keys
      expect(l10n.cashPaymentMethod, 'نقدًا');
      expect(l10n.cardPaymentMethod, 'بطاقة بنكية');
      expect(l10n.editItemTooltip, 'تعديل العنصر');
      expect(l10n.previousDayTooltip, 'اليوم السابق');
      expect(l10n.nextDayTooltip, 'اليوم التالي');
      expect(l10n.customerHasUnpaidDebt('1000'), contains('ديون غير مدفوعة'));
      expect(l10n.customerDeletedSuccess('أحمد'), contains('حذف'));
      expect(l10n.employeeDeletedSuccess('سعيد'), contains('حذف'));
      expect(l10n.supplierDeletedSuccess('الموزع'), contains('حذف'));
      expect(l10n.invalidBarcodeChecksum, contains('باركود'));
      expect(l10n.appTagline, 'إدارة الأعمال بالذكاء الاصطناعي');
    });

    test('AppLocalizations delegates support all 3 locales', () {
      const locales = [Locale('en'), Locale('fr'), Locale('ar')];
      for (final locale in locales) {
        expect(AppLocalizations.delegate.isSupported(locale), isTrue);
      }
    });
  });
}
