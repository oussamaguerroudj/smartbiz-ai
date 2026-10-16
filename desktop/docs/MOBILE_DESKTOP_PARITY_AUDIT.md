# Modiri AI Desktop — Mobile Parity, Architecture & Verification Audit

**Generated / Updated:** October 2026  
**Document Version:** 2.0.0 — Production Recovery & Verification  
**Target Platform:** Windows Desktop (`flutter build windows --release`)  
**Functional Benchmark:** Modiri AI Mobile Application (`mobile/lib/...`)  
**Visual Reference:** Modiri Web Application (`modiri-web-phase1`)  
**Storage Target:** `%LOCALAPPDATA%\ModiriAI\modiri_desktop.db`  

---

## 1. Executive Summary & Architecture Standard

The Modiri AI Windows Desktop application provides a full offline-first enterprise management suite designed for Algerian businesses (operating natively in Algerian Dinars - DZD) across six distinct industry verticals:

1. **Grocery / Superette / Supermarket** (`grocery`, `superette`, `supermarket`)
2. **Restaurant / Cafe** (`restaurant`, `cafe`)
3. **Clinic / Dental Clinic** (`clinic`, `dental_clinic`)
4. **Pharmacy** (`pharmacy`)
5. **Clothing / Fashion Retail** (`clothing`)
6. **Company / Enterprise / Services** (`company`)

### Non-Destructive Storage Policy
- **Primary Storage Path:** `%LOCALAPPDATA%\ModiriAI\modiri_desktop.db`
- **Safe Migration:** If the primary database does not yet exist, the desktop runtime searches for existing data in `%APPDATA%\Modiri AI\Modiri AI\modiri_desktop_v2.db` or `%APPDATA%\Modiri AI\Modiri AI\modiri_desktop.db` and copies it into place without wiping, recreating, or dropping any user tables, records, or synchronization queues.
- **Fail-Safe Opening:** If database opening encounters an error, the application halts with an explicit error instead of silently instantiating an empty file.

---

## 2. Six Business Verticals Parity Matrix

| Vertical | Primary Workflow | Mobile Implementation | Desktop Implementation | Parity Status | Verification Evidence |
|---|---|---|---|---|---|
| **1. Grocery / Superette** | Barcode POS, multi-cart parking, inventory, expiry dates, supplier purchases, customer credit ledger | `mobile/lib/features/sales/`, `mobile/lib/features/products/` | `desktop/lib/features/pos_sales/`, `desktop/lib/features/inventory/` | **VERIFIED** | Multi-cart (Cart 1/2/3), hardware HID barcode scanner wedge buffer with GTIN checksum, thermal receipt printing, slow-moving inventory filter, CSV export. |
| **2. Restaurant / Cafe** | Table management, order status flow, split/partial payments, kitchen inventory ingredients, no retail barcode POS | `mobile/lib/features/restaurant/` | `desktop/lib/features/restaurant/` | **VERIFIED** | Dynamic tables grid, table status toggle, order item addition/removal, partial payment tracking with remaining balance calculation, kitchen ingredients stock adjustment, non-duplicate revenue accounting. |
| **3. Clinic / Dental** | Doctor appointments calendar, patients waiting queue, call next patient, medical supply inventory | `mobile/lib/features/clinic/`, `mobile/lib/features/appointments/` | `desktop/lib/features/clinic/`, `desktop/lib/features/appointments/` | **VERIFIED** | Appointments calendar with date/time pickers and status toggles, patient queue management with priority chips, call next patient workflow, medical supplies stock tracking. |
| **4. Pharmacy** | Prescription POS, medication batches, expiration date tracking, batch number verification | `mobile/lib/features/pharmacy/`, `mobile/lib/features/products/` | `desktop/lib/features/pharmacy/`, `desktop/lib/features/pos_sales/` | **VERIFIED** | Batch expiry alerts (30-day window), batch creation modal with expiry and lot number, rapid barcode POS dispensing. |
| **5. Clothing / Retail** | Size, color, brand catalog tracking, barcode POS, supplier restocking, customer credit | `mobile/lib/features/clothing/`, `mobile/lib/features/sales/` | `desktop/lib/features/clothing/`, `desktop/lib/features/pos_sales/` | **VERIFIED** | Size/color/brand fields in product catalog, multi-cart retail POS, customer credit with FIFO allocation. |
| **6. Company / Enterprise**| Client project management, budget tracking, expense allocation, asset inventory | `mobile/lib/features/enterprise/`, `mobile/lib/features/expenses/` | `desktop/lib/features/enterprise/`, `desktop/lib/features/expenses/` | **VERIFIED** | Project portfolio view, project creation modal, budget tracking, milestone status tracking, corporate asset catalog. |

---

## 3. Financial Accounting Rules & Business Logic

The Desktop financial engine (`DesktopLocalFinancialCalculator`) strictly follows the Mobile application business rules:

1. **Distinction Between Sales Revenue and Cash Received:**
   - Sales revenue represents the total value of completed, non-cancelled sales transactions.
   - Cash received tracks actual monetary inflows (`paid_amount`, credit repayments, supplier downpayments).
   - Invoices with status `'unpaid'` or `'partial'` track the remaining balance under receivables (`credit_balance`), preventing phantom revenue from unpaid balances being mistaken for cash.

2. **Zero Duplicate Revenue Entries:**
   - Restaurant payments are recorded in `restaurant_payments` (and `restaurant_orders`).
   - Order completion does **not** insert redundant rows into the retail `sales` table.
   - Any legacy `sales` records matching `id LIKE 'REST-%'` are excluded from retail sales aggregation to prevent double-counting.

3. **No Phantom Deductions of Remaining Inventory:**
   - Ending inventory on hand is an **Asset**, never an expense.
   - Net Profit formula: `Net Profit = Gross Profit - Operating Expenses`.
   - Remaining inventory valuation (`stock_quantity * cost_price`) is reported as an asset on the balance sheet, never deducted from periodic net profit.

4. **Supplier Invoices & Inventory Flow:**
   - Recording a supplier purchase invoice creates `supplier_purchases` and `supplier_purchase_items`.
   - If products or restaurant ingredients match the purchase description, stock quantities and unit costs are automatically incremented and synchronized.
   - Immediate downpayments record a corresponding `supplier_payments` row, preserving Accounts Payable integrity.

---

## 4. Complete Localization Parity (EN, FR, AR RTL)

All 6 verticals and core screens support full trilingual parity without missing dictionary keys or hardcoded English/French fallback strings:
- **English (`en`)**: LTR layout, financial values formatted as `1,250.00 DZD`.
- **French (`fr`)**: LTR layout, standard Algerian commercial terms (`Facturation`, `Bons de livraison`, `DZD`).
- **Arabic (`ar`)**: RTL layout (`Directionality.rtl`), localized Arabic numerals and terms (`نقطة البيع`, `المخزون`, `د.ج`).
