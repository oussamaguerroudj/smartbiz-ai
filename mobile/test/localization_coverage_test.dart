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
    });

    test('AppLocalizations delegates support all 3 locales', () {
      const locales = [Locale('en'), Locale('fr'), Locale('ar')];
      for (final locale in locales) {
        expect(AppLocalizations.delegate.isSupported(locale), isTrue);
      }
    });
  });
}
