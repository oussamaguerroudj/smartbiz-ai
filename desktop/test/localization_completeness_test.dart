import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_desktop/core/localization/desktop_localizations.dart';

void main() {
  group('Desktop Localization Completeness & Parity Tests', () {
    final enLoc = ModiriLocalizations(const Locale('en'));
    final frLoc = ModiriLocalizations(const Locale('fr'));
    final arLoc = ModiriLocalizations(const Locale('ar'));

    test('All newly added keys return non-empty strings across EN, FR, and AR', () {
      final sampleKeys = [
        'pos_receipt_title',
        'receipt_invoice_prefix',
        'receipt_customer_prefix',
        'item_col_header',
        'qty_col_header',
        'total_col_header',
        'subtotal_colon',
        'discount_colon',
        'total_due_colon',
        'payment_method_colon',
        'receipt_thank_you',
        'financial_perf_statement',
        'period_prefix',
        'generated_prefix',
        'exec_financial_summary',
        'financial_metric_header',
        'amount_dzd_header',
        'notes_kpi_header',
        'gross_sales_revenue',
        'cogs_label',
        'cogs_desc',
        'gross_profit_label',
        'gross_profit_formula',
        'operating_expenses_label',
        'operating_expenses_desc',
        'net_operating_profit',
        'top_performing_products',
        'no_sales_period',
        'expenses_by_category',
        'no_expenses_period',
        'official_ledger_statement',
        'link_existing_customer_optional',
        'none_walkin_client',
        'client_patient_name_req',
        'service_visit_reason',
        'notes_remarks',
        'save_appointment_failed',
        'search_appointments_hint',
        'confirm_tooltip',
        'complete_tooltip',
        'cancel_tooltip',
        'delete_tooltip',
        'call_next_failed',
        'patient_queued_success',
        'queue_patient_failed',
        'queue_cancelled_success',
        'queue_cancel_failed',
        'update_patient_failed',
        'complete_visit_failed',
        'total_greater_downpayment',
        'credit_sale_recorded',
        'search_debtors_hint',
        'delete_failed_prefix',
        'valid_amount_up_to',
        'removed_prefix',
        'salary_logged_for',
        'attendance_payroll_history',
        'log_today_attendance',
        'attendance_logged_for',
        'disbursed_salary_history',
        'expense_category_req',
        'amount_dzd_req',
        'description_payee_note',
        'confirm_delete_expense',
        'no_expenses_category',
        'edit_expense',
        'delete_expense',
        'create_invoice_failed',
        'print_preview_error',
        'search_invoices_hint',
        'medicine_product_name_req',
        'lot_batch_number_req',
        'batch_qty_units_req',
        'save_batch_failed',
        'delete_batch_error',
        'search_batches_hint',
        'manual_wedge_sku_hint',
        'search_products_barcode_hint',
        'max_stock_reached',
        'added_units_to',
        'error_loading_inventory',
        'filter_reports_hint',
        'cost_per_unit_dzd_req',
        'reorder_point_req',
        'search_ingredients_hint',
        'delete_table_error',
        'create_order_error',
        'supplier_name_req',
        'warehouse_address_label',
        'search_suppliers_hint',
        'hero_restaurant_badge',
        'hero_restaurant_subtitle',
        'hero_clinic_badge',
        'hero_clinic_subtitle',
        'hero_pharmacy_badge',
        'hero_superette_badge',
        'hero_clothing_badge',
        'hero_company_badge',
        'hero_general_badge',
        'todays_appointments_label',
        'waiting_room_queue_label',
        'clinical_revenue_label',
        'expiring_30_days_label',
        'low_stock_formulations_label',
        'dispensary_sales_label',
        'active_medications_label',
        'boutique_sales_label',
        'garments_in_stock_label',
        'unique_models_label',
        'low_stock_garments_label',
        'gross_sales_label',
        'transactions_today_label',
        'low_stock_groceries_label',
        'customer_credit_due_label',
        'active_projects_label',
        'monthly_invoiced_label',
        'monthly_payroll_label',
        'cumulative_ledger_desc',
        'period_gross_revenue',
        'period_net_profit',
        'dead_stock_chip',
        'connection_failed_offline_hint',
        'enter_6digit_code',
        'test_connection_button',
      ];

      for (final key in sampleKeys) {
        final enVal = enLoc.get(key);
        final frVal = frLoc.get(key);
        final arVal = arLoc.get(key);

        expect(enVal, isNotEmpty, reason: 'EN missing key: $key');
        expect(enVal, isNot(contains('[$key]')), reason: 'EN returned fallback placeholder for key: $key');

        expect(frVal, isNotEmpty, reason: 'FR missing key: $key');
        expect(frVal, isNot(contains('[$key]')), reason: 'FR returned fallback placeholder for key: $key');

        expect(arVal, isNotEmpty, reason: 'AR missing key: $key');
        expect(arVal, isNot(contains('[$key]')), reason: 'AR returned fallback placeholder for key: $key');
      }
    });

    test('Locale resolution and fallback behavior', () {
      final locFallback = ModiriLocalizations(const Locale('es')); // unsupported locale
      // Should fallback gracefully to English
      expect(locFallback.get('dashboard'), equals('Dashboard'));
    });

    test('Arabic strings contain authentic RTL Arabic characters', () {
      final arVal = arLoc.get('pos_receipt_title');
      expect(arVal, contains('مديري'));

      final arVal2 = arLoc.get('financial_perf_statement');
      expect(arVal2, contains('بيان'));

      final arVal3 = arLoc.get('search_suppliers_hint');
      expect(arVal3, contains('الموردين'));
    });
  });
}
