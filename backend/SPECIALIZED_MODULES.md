# MODIRI — Specialized Business Modules

## 15. Dashboard-family simplification (post-audit-Phase-4, corrected in
## Phase 4.1)

The onboarding picker used to expose all 24 `business_type_enum` values
as separate tiles. It now shows exactly **6 dashboard families**:
Market / Store, Clothing Store, Restaurant / Café, Clinic / Medical,
Pharmacy, Enterprise / Company — matching the 6 dashboards that actually
exist as reusable groups (Supérette covers Market/Store).

**Phase 4.1 correction:** the first pass of this simplification dropped
`company` (Enterprise) from the picker even though it has always had a
real, fully-built dashboard (`EnterpriseMainDashboardScreen`) — see §14
below. That was wrong and has been reverted: `company` is back in
`kSelectableBusinessTypes` as the 6th tile, "Enterprise / Company". This
was a picker/label-only fix — `main_shell.dart`'s `'company' =>
EnterpriseMainDashboardScreen()` routing, the `company` DB enum value,
and every existing Enterprise account were never touched by the original
mistake and needed no change here.

**Nothing was removed or renamed at the database level** — purely a
picker-level and routing-level change, per the "prefer compatibility
mapping over destructive changes" rule already established for this
enum (see migration 016's own comment).

- **Mobile** (`business_type_screen.dart`): added
  `kSelectableBusinessTypes` — the 6 canonical `BusinessType` values the
  picker now iterates over, instead of `BusinessType.values` (24). The
  `BusinessType` enum itself, `apiValue`, and `fromApiValue` are
  UNCHANGED — every legacy value still round-trips correctly, and
  `main.dart`'s `BusinessType.company` fallback still compiles.
  Canonical values chosen were `grocery`/`restaurant`/`clinic` (not
  `retail_store`/`cafe`/`dental_clinic`) specifically because those
  three already carry full AR/FR/EN translations — avoids new
  translation work while broadening the displayed label/description to
  the new family framing ("Market / Store", "Restaurant / Café",
  "Clinic / Medical").
- **Mobile** (`main_shell.dart`): a real pre-existing gap was found and
  closed while doing this — `cafe` and `dental_clinic` are valid
  `business_type_enum` values but were never routed anywhere by any of
  the four per-vertical switch functions (`_dashboardTabFor`,
  `_middleTabsFor`, `_middleNavItemsFor`, `_MoreMenu._items`); an
  account with either value fell through to generic CORE. Both are now
  folded into their matching family exactly like
  `grocery`/`supermarket`/`retail_store` already were for Supérette:
  `'clinic' || 'dental_clinic'` and `'restaurant' || 'cafe'` wherever
  the switches branch on business type.
- **Backend**: `clinic.routes.js`'s and `restaurant.routes.js`'s
  `requireBusinessType()` gates extended the same way (`'clinic',
  'dental_clinic'` / `'restaurant', 'cafe'`), so an account with either
  legacy value can actually reach the specialized endpoints its
  dashboard now calls — previously a `dental_clinic`/`cafe` account
  would have been 403'd by every clinic/restaurant API call even if the
  Flutter routing had matched it. `companies.routes.js`'s `VALID_TYPES`
  is UNCHANGED (still all 24) — validation stays permissive so an
  existing account's stored value is never rejected on a future
  unrelated update.
- **Test**: `businessType.middleware.test.js`'s `EXPECTED` matrix
  updated to assert `dental_clinic`/`cafe` are now admitted by the
  clinic/restaurant guards respectively — this test would otherwise
  have started failing (by design — it's an exact allow/deny matrix
  across all 24 enum values) the moment the guards changed.

**Removed from the picker, not from the codebase** (no dashboard code
exists for any of these): `workshop`, `beauty_salon`, `barbershop`,
`gym`, `hotel`, `medical_laboratory`, `car_repair`, `electronics_store`,
`bakery`, `law_office`, `accounting_office`, `real_estate_agency`,
`education_center`, `other`, `supermarket`, `retail_store`, `cafe`,
`dental_clinic` — the last four aren't individually removed so much as
no longer separately tiled, since a new user picks the family and gets
the canonical value. `company` (Enterprise) is **not** in this list —
see the Phase 4.1 correction above; it has its own tile again.

**Not done as part of this**: `dashboard_screen.dart`'s header (`'${company.name} · ${company.businessType}'`)
and `business_setup_screen.dart`'s read-only business-type field both
display the raw/plain (non-localized) string — a pre-existing gap
unrelated to this change, not fixed here to keep the diff focused.

Status: **Business Type system expanded (24 types) + Clinic,
Restaurant, Pharmacy, Supérette/General Store, Clothing Store and
Enterprise/Company fully implemented as the six reference verticals.**
Every other vertical (Gym, Hotel, ...) follows the exact pattern
documented below — none of them are built yet.

Nothing in this batch touched, renamed, or removed any CORE feature
(Sales, Invoices, Expenses, Products, Customers, Suppliers, Employees,
Reports, AI, Credit). Every specialized module is purely additive.

## 1. The CORE + SPECIALIZED split (Ch. 2)

```
CORE (unchanged, works for every business_type)
├── Dashboard, Sales, Credit, Invoices, Expenses
├── Products, Customers, Suppliers, Employees
├── Reports, AI Assistant, Notifications
│
SPECIALIZED (additive, gated by companies.business_type)
├── clinic/         ✅ implemented
├── restaurant/      ✅ implemented
├── pharmacy/         ✅ implemented (dashboard-only, no new tables)
├── superette/        ✅ implemented (dashboard-only, no new tables)
├── clothing/         ✅ implemented (dashboard-only;
│                        adds 3 nullable columns to CORE `products`)
├── enterprise/       ✅ implemented (this batch — dashboard + Projects;
│                        adds one table, `enterprise_projects`)
├── gym/              — documented pattern only, not built
├── hotel/            — documented pattern only, not built
└── ... (15 more)     — documented pattern only, not built
```

A business account with `business_type = 'gym'` today gets the full
CORE feature set and nothing extra — exactly as safe/correct a default
as `business_type = 'clinic'` was before this batch.

## 2. Business Type system (Ch. 1)

- **Backend**: `business_type_enum` (Postgres) — expanded from 7 to 24
  values by migration `016_expand_business_types.sql` (purely additive
  `ALTER TYPE ... ADD VALUE`, zero risk to existing rows). Validated
  server-side in `companies.routes.js`'s `VALID_TYPES` array — keep
  these two lists in sync when adding a 25th type.
- **Frontend**: `BusinessType` enum in `business_type_screen.dart`, with
  an `apiValue` extension mapping each Dart member to its exact DB
  string. **Important**: always send `businessType.apiValue`, never
  `businessType.name` — a real bug from before this batch (fixed in
  `business_setup_screen.dart`) where `.name` happened to work only
  because the original 7 types' Dart names were coincidentally
  snake_case-free single words.
- New types' labels/descriptions are English-only for now
  (`localizedLabel`/`localizedDescription` fall back to the plain
  `label`/`description` getters) — translating the 17 new types into
  AR/FR is a follow-up, not done in this batch.

## 3. The exact pattern for adding a new vertical

Using Clinic and Restaurant as the template, adding e.g. **Gym**
means:

1. **Migration**: `NNN_create_gym_tables.sql` — tables named
   `gym_*` (matches Ch. 29's naming convention), each carrying
   its own `company_id` for direct tenant-isolation filtering (never
   isolate only via a JOIN — see §4 below). **Skip this step entirely**
   if the vertical's data already fits CORE tables, the way Pharmacy's
   did — check first (§11) before assuming a vertical needs new tables.
2. **Backend module**: `backend/src/modules/gym/` with the same
   core files every other module has (`gym.routes/controller/
   service/repository.js`, plus `validators.js` only if the module has
   its own create/update endpoints — Pharmacy's doesn't, since it has
   none of its own). Mount it in `routes/index.js` under its own prefix
   (`router.use('/gym', gymRoutes)`) — never touches any other module's
   routes.
3. **Reuse, don't duplicate**: Clinic reused `employees.position` for
   "who's a doctor" instead of a new `doctors` table; Restaurant did the
   same for "Waiter"/"Cashier"; Pharmacy went further and reused
   `products`/`sales`/`suppliers` wholesale, adding no new tables at
   all. Always check whether an existing CORE table already models the
   vertical's data before creating a specialized one.
4. **AI tools**: add 1-4 narrow tools to `ai.tools.js` (see
   `get_clinic_queue_status`/`get_clinic_dashboard`/
   `get_patient_last_visit`, `get_restaurant_dashboard`/
   `get_restaurant_tables_status`/`get_restaurant_active_orders`, and
   `get_pharmacy_dashboard`/`get_expiring_products` for the pattern)
   and register them in both `TOOL_IMPLEMENTATIONS` and
   `TOOL_DEFINITIONS`. They're safe to leave registered even for
   non-matching companies — the tables are just empty, so the model
   naturally has nothing to report. A tool doesn't have to be
   vertical-exclusive either — `get_expiring_products` was added
   business-type-agnostic since `products.expiration_date` exists for
   every company, not just pharmacy.
5. **Flutter**: `lib/features/gym/{data,domain,presentation}` —
   a repository, models, and however many screens the vertical actually
   needs (Clinic needed 4, Restaurant needed 5, Pharmacy needed only 1 —
   a specialized dashboard reusing CORE Products/Sales/Suppliers
   screens for everything else).
6. **Navigation**: at minimum, one more arm in `main_shell.dart`'s
   `_dashboardTabFor` (every vertical needs this). Only add arms to
   `_middleTabsFor`, `_middleNavItemsFor`, and `_MoreMenu._items` too if
   the vertical actually needs different tabs/menu items than CORE's
   Sales/Inventory + full More list — Pharmacy proved this isn't always
   necessary; don't add empty/no-op arms "for consistency".
7. **l10n**: add real translated strings for a NEW vertical's UI text
   from day one where practical. Restaurant's own new screen labels
   were hardcoded English in this batch — same pragmatic call already
   made for Customers/Suppliers/AI Scanner/AI Insights in
   `main_shell.dart` — pending a follow-up translation pass across all
   of these at once, rather than each vertical inventing its own
   partial arb additions. Pharmacy added no new UI strings needing
   translation beyond that.

## 4. Data isolation (Ch. 24) — non-negotiable

Every specialized table has its own `company_id`, exactly like every
CORE table. Every specialized repository function takes `companyId` as
its first argument and binds it directly into `WHERE company_id = $1`
— never relies on a JOIN through another table to establish tenant
scope. This mirrors `ai_tools_isolation.test.js`'s exact guarantee for
the AI module — the same test file's `test.each` loop now also covers
`get_clinic_queue_status`/`get_clinic_dashboard`/`get_patient_last_visit`
automatically (it iterates every registered tool, clinic tools
included).

**Not yet built**: a dedicated isolation test for `clinic.repository.js`
itself (separate from the AI-tools test) — every clinic query *does*
filter by `company_id` (verify by reading `clinic.repository.js`
directly), but no automated test asserts this the way
`ai_tools_isolation.test.js` does for the AI layer. Worth adding before
a second vertical is built, so the test pattern itself becomes reusable
too.

## 5. Role-based access (Ch. 25) — explicitly deferred

The app currently has exactly two roles: `owner` and `staff`
(`user_role_enum`). Ch. 25 asks for granular roles (Doctor,
Receptionist, Waiter, Cashier...) with different visible features per
role. **This was not built in this batch** — Clinic's endpoints are
reachable by any authenticated `staff` or `owner` user of that company,
same as every CORE endpoint today. Implementing real per-role UI/API
gating is a meaningfully sized separate piece of work (a new
permissions table or an extended role enum, checked in
`authMiddleware` or a new middleware layer) — flagged here rather than
half-built.

## 6. Dashboard adaptation (Ch. 27)

**Update:** the MAIN Dashboard tab (tab 0 in `main_shell.dart`) now
switches content by `business_type`, closing the gap this section used
to flag. `dashboard_screen.dart` itself is still **completely
untouched** — the switch lives one layer up, in `main_shell.dart`'s
`_dashboardTabFor(businessType)`, which resolves tab 0 to
`ClinicMainDashboardScreen` (a new file,
`clinic/presentation/screens/clinic_main_dashboard_screen.dart`) when
`businessType == 'clinic'`, and to the generic `DashboardScreen`
otherwise — including `null`/not-yet-set during onboarding and every
business type without a specialized MAIN dashboard yet. This keeps the
same "smallest possible diff" property the original decision was
protecting: the CORE dashboard file has zero new branches in it, and
every non-clinic company's experience is byte-for-byte unchanged.

`ClinicMainDashboardScreen` deliberately re-implements the CORE
dashboard's structural chrome (the `GradientHero` header, the
overlapping KPI-card row with the same `_kKpiCardHeight`/`_kKpiOverlap`
constants, `AnimatedCounter`, `FadeSlideIn` stagger) rather than
importing `dashboard_screen.dart`'s private widgets — those are
file-private (`_DashboardHeader`, `_KpiCard`), so a byte-identical
local copy was the only way to reuse the exact visual language without
making them public and widening dashboard_screen.dart's own surface
area. Content is entirely clinic-specific: top KPI row is Patients
Today / Waiting / Today's Revenue (never product sales), a second row
adds Appointments Today / Completed Today / Outstanding Payments, then
a patient-queue snapshot card (next patient, who's currently in
consultation, how many are waiting) and a clinic quick-actions row (Add
Patient, New Appointment, Call Next Patient, Record Payment) replace
the generic dashboard's sales trend chart and low-stock alert.

The old standalone `ClinicDashboardScreen` (reached from "More", per
the original §3.6 placement) is now unreached from navigation — its
"More" menu entry was removed since it would otherwise duplicate the
new main-tab screen with slightly less content (no queue snapshot, no
quick actions). The screen/file itself was left in place rather than
deleted, since `clinic_main_dashboard_screen.dart` reuses its
`clinicDashboardProvider` via a `show` import; it would need to be
either deleted or repurposed (e.g. as a deep-link target) in a future
cleanup pass.

**Still not done:** the same treatment for any other vertical beyond
Clinic, Restaurant, and Pharmacy — there is no `GymMainDashboardScreen`,
`HotelMainDashboardScreen`, etc. Adding one means: build the vertical's
dashboard screen (following `ClinicMainDashboardScreen`/
`RestaurantMainDashboardScreen`/`PharmacyMainDashboardScreen`'s pattern
above), then add one more arm to `_dashboardTabFor`'s `switch` in
`main_shell.dart` — never touching the arms already there.

## 7. Full navigation specialization (Ch. 1, 13, 20)

**Update:** specialization now goes beyond the Dashboard tab's content —
it reaches into which TABS and which More-menu ITEMS exist at all, per
`business_type`, in `main_shell.dart`:

- **Bottom nav tabs 1-2**: CORE/retail keeps Sales + Inventory
  (unchanged). For `clinic`, these become Appointments + Patients
  (`AppointmentsScreen`, `ClinicPatientsScreen` — both already-existing
  screens, just promoted to tab slots instead of only being reachable
  from "More"). A clinic owner never lands on a product/sales tab.
- **More menu**: for `clinic`, every retail-only item is dropped
  entirely (not just hidden) — Invoices, Customers, Suppliers, Credit,
  AI Invoice Scanner — none of which a clinic has data for. Appointments
  is dropped from More too since it's now a tab (avoiding the same
  screen being reachable two different ways, same rule already applied
  to the old `ClinicDashboardScreen` in §6). Waiting Room
  (`ClinicQueueScreen`) is added instead — a real, frequently-used
  clinic screen that doesn't have its own tab slot. Expenses, Employees,
  Reports, AI Assistant, AI Insights, Notifications and Settings stay,
  since they're genuinely business-type-agnostic. Every other business
  type (including `null`/not-yet-set) keeps the exact original CORE
  list and tabs, byte-for-byte.

**Update:** Restaurant now gets the exact same treatment as Clinic —
tabs 1-2 become Orders + Tables (`RestaurantOrdersScreen`,
`RestaurantTablesScreen`), and the More menu drops every retail/product
item (Invoices, Customers, Suppliers, Credit, AI Invoice Scanner — a
restaurant has no invoiced products per Ch. 17) plus Orders/Tables
themselves (now tabs), adding Menu and Reservations instead (real
restaurant screens with no tab slot of their own). Expenses, Employees,
Reports, AI Assistant, AI Insights, Notifications and Settings stay,
same as Clinic. See §10 for the full Restaurant writeup.

This is implemented via three small per-vertical functions in
`_MainShellState` (`_dashboardTabFor`, `_middleTabsFor`,
`_middleNavItemsFor`) plus `_MoreMenu._items`, each a `switch` on
`businessType` — CORE is always the `_` default branch, so a business
type with no specialized branch yet falls through to the exact original
behavior unchanged.

**Update (Pharmacy):** Pharmacy deliberately has NO arm in
`_middleTabsFor`, `_middleNavItemsFor`, or `_MoreMenu._items` — it
falls through to the CORE default in all three, since Sales/Inventory
tabs and the full Suppliers/Customers/Reports More menu already are
what a pharmacy needs (see §11). Only `_dashboardTabFor` gained a
`'pharmacy'` arm. This is the first vertical to prove the pattern
doesn't require touching all four functions — only add an arm where
the vertical actually diverges from CORE.

**Known, deliberately out-of-scope pre-existing issue found while doing
this:** `reports_screen.dart` renders its own separate
`FuturisticNavBar` (hardcoded English labels, and its `onTap` pops back
to `MainShell` regardless of which index was tapped) instead of being
one of `MainShell`'s own `IndexedStack` tabs. That bug predates this
batch and is unrelated to business-type specialization — flagged here
rather than fixed, to keep this batch's diff focused.

**Still not done:** Reports' own internal labels/data ("Sales count",
"Top Products") are still retail-flavored even when opened from a
clinic account — the endpoint it calls returns revenue/expenses/profit
generically, so the numbers are correct, but the wording isn't
clinic-specific yet. Specializing Reports' terminology per vertical is
a reasonable next follow-up, not part of this batch.

## 8. What's genuinely NOT done yet (be honest about this)

- 16 of 21 requested verticals (only Clinic, Restaurant, Pharmacy,
  Supérette/General Store, and Clothing Store exist).
- Granular RBAC (§5) — applies to Restaurant, Pharmacy, Supérette and
  Clothing too (no Waiter-only/Cashier-only view for Restaurant; no
  Pharmacist-only view for Pharmacy; no Cashier-only view for
  Supérette/Clothing; any staff/owner user can do anything on any
  endpoint).
- File upload storage for `clinic_documents` (the table/endpoint exist;
  no actual file storage service is wired up in this project yet — the
  API accepts a `fileUrl` string, meaning the client would need its own
  upload mechanism, e.g. to S3/Cloudinary, before calling
  `POST /clinic/documents`).
- Doctor-specific filtered views (Ch. 3.G "Doctor Dashboard" showing
  *only that doctor's* patients) — the current Queue/Dashboard show the
  whole clinic, not scoped per logged-in doctor (ties into §5's RBAC
  gap: there's no reliable way yet to know "which employee record is
  the currently logged-in user"). Restaurant has the analogous gap: no
  per-waiter order filtering.
- Calendar view for appointments (list view only). Restaurant's
  Reservations screen is likewise a flat list, not a calendar/timeline.
- A dedicated `clinic.repository.js` isolation test (§4) — same gap now
  also applies to `restaurant.repository.js`, `pharmacy.repository.js`,
  `superette.repository.js` and `clothing.repository.js` (every query
  *does* filter by `company_id`; no dedicated automated test asserts it
  beyond the shared `ai_tools_isolation.test.js` coverage of each
  vertical's own AI tools).
- ~~The main CORE `dashboard_screen.dart` still does not switch its own
  content by `business_type`~~ — **done**, see updated §6: the switch
  now lives in `main_shell.dart` (tab 0 resolves to
  `ClinicMainDashboardScreen` / `RestaurantMainDashboardScreen` /
  `PharmacyMainDashboardScreen` per business type), not inside
  `dashboard_screen.dart` itself.
- ~~Enterprise/Company dashboard (Ch. 19) is not built yet~~ — **done**,
  see §14. (Original note, kept for history: Clinic,
  Restaurant, Pharmacy, Supérette, and Clothing are the five fully
  specialized verticals so far. Enterprise is the odd one out: Ch. 19
  asks for Clients, Projects, Employees, Salaries, Invoices, Payments —
  `customers`(-as-clients)/`employees`/`invoices` already exist, but
  there is no `projects` table anywhere in this codebase, so (per
  Ch. 21) a real Enterprise vertical needs its own new
  `enterprise_projects`-style table/migration, not just a dashboard
  aggregate over existing CORE data the way Pharmacy/Supérette/Clothing
  all were.
- Clothing Store (§13): no Size/Color/Brand input fields in the
  existing CORE product-creation form yet — the columns and the API
  accept them, but no Flutter form is wired to set them, so today
  they're only settable via a direct API call. No Returns KPI/flow (no
  returns/refunds table exists anywhere in this codebase — flagged
  rather than fabricated, see §13).
- Restaurant-specific: no partial refunds (a refund always returns the
  full amount paid so far, same simplification Clinic made); no
  kitchen-printer/ticket integration; `RestaurantOrdersScreen`'s "move
  to next stage" is a single linear path (pending → preparing → ready →
  served → completed) with no way to jump stages or reopen a completed
  order; Tables screen cycles status with a single tap rather than a
  full status picker.
- Pharmacy-specific: no "Purchase costs" KPI — there is no
  purchases-transaction ledger anywhere in this codebase (a
  pre-existing gap, already documented in `ai.tools.js`'s
  `get_suppliers` comment), so this was left out rather than
  fabricated; only real inventory-value and sales-revenue figures are
  shown. No dedicated Expiry Alerts screen yet (the backend endpoint
  `GET /pharmacy/expiring-products` exists and is paged, but the
  dashboard only shows a top-3 preview inline — no Flutter screen calls
  the full endpoint yet). No barcode-scan-to-restock flow.

## 11. Pharmacy vertical (Ch. 15) — added in this batch

Third specialized vertical, and the first to prove §3's pattern doesn't
always mean new tables:

- **No migration.** `products.expiration_date` (migration 006) was
  already reserved for exactly this and simply unused until now;
  `products`/`sales`/`sale_items`/`suppliers` already model everything
  Ch. 15 asks for (Products, Stock, Sales, Purchases-as-cost-tracking,
  Suppliers). Per Ch. 21's "reuse existing backend/database/business
  logic whenever possible", no `pharmacy_*` tables were created.
- `backend/src/modules/pharmacy/` — repository/service/controller/
  routes only (no `validators.js`; the module has no create/update
  endpoints of its own — those all remain `/products`, `/sales`,
  `/suppliers`). `pharmacy.repository.js` adds exactly what didn't
  exist anywhere else: `expiringProducts`/`expiringCount`/
  `expiredCount` (Ch. 15's "Expiring products"), `lowStockProducts`/
  `lowStockCount` (same formula the CORE dashboard already uses,
  duplicated as a short inline query rather than factored out — this
  codebase already does the same for the same query in
  `dashboard.routes.js` and `ai.tools.js`), `inventoryValue` (cost AND
  retail value of everything in stock), and `suppliersCount` (no
  dedicated suppliers repository module exists to import — its query
  lives inline in `suppliers.routes.js` — so this is queried directly).
  `pharmacy.service.js`'s `getDashboard` composes all of this plus
  `salesSummaryForRange`/`bestSellingProducts`, both intentionally
  copying the exact revenue/grossProfit/topProducts formulas already
  established in `dashboard.routes.js` and `reports.routes.js` rather
  than inventing new ones — `todayNetProfit` is revenue minus operating
  expenses (matching the CORE dashboard and Reports' own `netProfit`),
  `todayGrossProfit` is the cost-of-goods-aware figure from
  `sale_items.line_profit` (matching Reports' own `grossProfit`),
  reported as two separate fields rather than picked-and-guessed one.
- **Deliberately not built**: a "Purchase costs" figure. There is no
  purchases-transaction ledger anywhere in this codebase — confirmed by
  `ai.tools.js`'s own `get_suppliers` comment, which already documents
  this exact gap. Per Ch. 21's explicit "do not fake data" rule, no
  today's-purchases number was invented; only the real, queryable
  inventory-value snapshot is shown instead.
- Mounted at `/pharmacy`: `GET /dashboard` (the full aggregate) and
  `GET /expiring-products?days=N` (a paged, uncapped list — the
  dashboard aggregate only returns a 10-item preview).
- 2 AI tools: `get_pharmacy_dashboard` (calls the same
  `pharmacy.service.getDashboard` the dashboard screen calls, per
  Ch. 21's single-source-of-truth rule) and `get_expiring_products` —
  the latter deliberately NOT gated to pharmacy in its description or
  implementation, since `products.expiration_date` exists for every
  business type (useful for a Supérette/grocery account too, once one
  exists). Both registered in `TOOL_IMPLEMENTATIONS`/`TOOL_DEFINITIONS`,
  automatically covered by `ai_tools_isolation.test.js`.
- Flutter: `lib/features/pharmacy/{data,domain,presentation}` — a
  repository, `PharmacyDashboardStats`/`PharmacyLowStockProduct`/
  `PharmacyExpiringProduct`/`PharmacyBestSeller` models, and exactly
  ONE screen: `PharmacyMainDashboardScreen`. Same `GradientHero`/
  overlapping-KPI-card/`AnimatedCounter`/`FadeSlideIn` chrome as
  Clinic's and Restaurant's own main dashboards. Top KPI row: Today's
  Revenue / Today's Profit (net) / Transactions. Second row: Low Stock
  count / Expiring Soon count / Inventory Value (retail). Body: a Stock
  Alerts card listing expiring and low-stock products (Ch. 15's
  "Low-stock medicines/products" + "Expiring products" alerts) instead
  of a patient queue or an orders board, and quick actions that open
  the existing CORE `ProductsListScreen`/`SuppliersScreen` — not new
  Pharmacy-specific screens, since those CORE screens already are the
  right tool.
- `main_shell.dart`: added ONLY the `'pharmacy'` arm to
  `_dashboardTabFor`. `_middleTabsFor`, `_middleNavItemsFor`, and
  `_MoreMenu._items` were intentionally left untouched — a pharmacy
  account keeps the exact CORE Sales/Inventory tabs and full CORE More
  menu (Suppliers, Customers, Invoices, Credit, Reports, AI, ...),
  since Ch. 15's own feature list (Products, Stock, Sales, Purchases,
  Suppliers, Customers) is just CORE's feature list. This is the first
  vertical to demonstrate that not every one of the four `main_shell.dart`
  switch functions needs a new arm — only add one where a vertical
  genuinely diverges from CORE, per §3.6's updated guidance.

**Not done as part of this**: see §8's Pharmacy-specific bullets
(no Purchase-costs KPI — data doesn't exist to compute it honestly; no
dedicated Expiry Alerts screen consuming the full paged endpoint yet;
no barcode-scan-to-restock flow). No dedicated
`pharmacy.repository.js` isolation test yet (§4's gap, same as Clinic's
and Restaurant's).

## 12. Supérette / General Store vertical (Ch. 16) — added in a later batch

Fourth specialized vertical, built strictly by following §11's Pharmacy
pattern — the second vertical to need zero new tables:

- **No migration.** `products`/`sales`/`sale_items`/`suppliers`/
  `customers` (with its existing `balance_due` column, already used by
  the CORE `credit` module) already model everything Ch. 16 asks for:
  Products, Stock, Sales, Purchases-as-cost-tracking, Suppliers,
  Customers, and Credit/customer debt. Per Ch. 21, no `superette_*`
  tables were created.
- `backend/src/modules/superette/` — repository/service/controller/
  routes only, same shape as `pharmacy`'s (no `validators.js`; no
  create/update endpoints of its own — those stay `/products`,
  `/sales`, `/suppliers`, `/customers`, `/credit`).
  `superette.repository.js` reuses `pharmacy.repository.js`'s exact
  `salesSummaryForRange`/`bestSellingProducts`/`lowStockProducts`/
  `lowStockCount`/`suppliersCount` formulas (Ch. 21's
  single-source-of-truth rule means these are copied, not
  reimplemented differently), renames pharmacy's `inventoryValue` to
  `stockValue` (Ch. 16 says "Stock value", not "Inventory value" —
  same query, vertical-appropriate naming), and adds two things
  Pharmacy's dashboard has no equivalent for: `customerDebt` (total
  outstanding `balance_due` across all customers, plus the top 5
  debtors — the same query `get_customers_with_debt` already uses in
  `ai.tools.js`, kept in sync here) and `customersCount`.
  **Deliberately NOT duplicated here**: `expiringProducts`/
  `expiringCount`. Ch. 16 doesn't list expiry the way Ch. 15 does for
  Pharmacy, and `pharmacy.repository.js`'s versions are already
  business-type-agnostic queries over `products.expiration_date` (that
  file's own doc comment already says so) — a future Supérette screen
  that wants an expiry widget should import pharmacy's functions
  directly rather than a second copy being created.
- `superette.service.js`'s `getDashboard` composes all of the above,
  same `todayNetProfit` (revenue − operating expenses, matching CORE/
  Reports/Pharmacy) vs `todayGrossProfit` (COGS-aware, from
  `sale_items.line_profit`) split Pharmacy already established.
- Mounted at `/superette`: `GET /dashboard` only — no dedicated
  expiring-products-style second endpoint, since Supérette has no
  equivalent paged list yet.
- 1 AI tool: `get_superette_dashboard` (calls
  `superette.service.getDashboard`, per Ch. 21's single-source-of-truth
  rule), registered in `TOOL_IMPLEMENTATIONS`/`TOOL_DEFINITIONS`,
  automatically covered by `ai_tools_isolation.test.js`'s `test.each`
  loop (verified: 21/21 AI-tool isolation tests pass, including this
  new one).
- Flutter: `lib/features/superette/{data,domain,presentation}` — a
  repository, `SuperetteDashboardStats`/`SuperetteLowStockProduct`/
  `SuperetteBestSeller`/`SuperetteDebtor` models, and exactly ONE
  screen: `SuperetteMainDashboardScreen`. Same `GradientHero`/
  overlapping-KPI-card/`AnimatedCounter`/`FadeSlideIn` chrome as every
  other vertical's main dashboard. Top KPI row: Today's Revenue /
  Today's Profit (net) / Transactions — identical to Pharmacy's. Second
  row: Low Stock count / Customer debt (total) / Stock value (retail).
  Body: a Stock Alerts card (same shape as Pharmacy's, minus the expiry
  section) plus a NEW Customer Debt card listing the biggest
  outstanding balances (Ch. 16's own point of difference from
  Pharmacy), and quick actions opening the existing CORE
  `ProductsListScreen`/`SuppliersScreen`.
- `main_shell.dart`: added ONLY a `'grocery' || 'supermarket' ||
  'retail_store'` arm to `_dashboardTabFor` (Dart 3 or-pattern — one
  screen, three business_type values, since Ch. 16 treats a grocery
  store, a supermarket and a generic retail store as the same business
  model). `_middleTabsFor`, `_middleNavItemsFor`, and
  `_MoreMenu._items` were intentionally left untouched, exactly like
  Pharmacy — CORE's Sales/Inventory tabs and full More menu (Suppliers,
  Customers, Invoices, Credit, Reports, ...) already are what a
  supérette needs.

**Not done as part of this**: no dedicated Customer Debt / Stock Alerts
full-list screens (both are inline dashboard previews only, same
"top-N preview, no dedicated screen yet" gap Pharmacy's Expiry Alerts
has). No dedicated `superette.repository.js` isolation test yet (§4's
gap, same as every other vertical). No "Purchase costs" KPI, for the
exact same reason as Pharmacy (§8/§11) — no purchases-transaction
ledger exists anywhere in this codebase.

## 13. Clothing Store vertical (Ch. 18) — added in a later batch

Fifth specialized vertical, and the first one where §11/§12's
"no-new-tables" pattern genuinely didn't fully apply:

- **One small additive migration**, unlike Pharmacy/Supérette.
  Migration `020_add_clothing_attributes.sql` adds three plain
  nullable columns — `size`, `color`, `brand` — to the existing CORE
  `products` table. Ch. 18 explicitly lists Size/Color/Brand as
  attributes that must be visible, and (unlike Pharmacy's
  `expiration_date`) no column anywhere already modeled them — only
  `category` did. Per Ch. 21's "do not fake data" rule, the honest
  options were either fabricate nothing and just document the gap
  (Pharmacy's approach for its missing Purchase-costs figure), or add
  the columns; since these are simple, optional, purely additive
  scalar columns with zero risk to any existing row or any other
  business type (they stay NULL forever for everyone else, exactly
  like `expiration_date` did until Pharmacy), adding them was the
  better call here. `products.repository.js` (CORE) was extended
  — NOT replaced — to read/write `size`/`color`/`brand` alongside every
  field it already handled; `products.controller.js`/`.service.js`/
  `.validators.js` needed zero changes since `req.body` already flows
  through untouched and these three fields are optional everywhere.
- `backend/src/modules/clothing/` — repository/service/controller/
  routes, same 4-file shape as `pharmacy`/`superette` (no
  `validators.js`, no create/update endpoints of its own).
  `clothing.repository.js` copies Supérette's exact
  `salesSummaryForRange`/`lowStockProducts`/`lowStockCount`/
  `stockValue`/`suppliersCount`/`customerDebt`/`customersCount`
  formulas verbatim (Ch. 21's single-source-of-truth rule — these
  aren't clothing-specific, so they aren't reinvented), and adds two
  genuinely new things: `bestSellingProducts` now also selects
  `size`/`color`/`brand` per row (so "what's selling" answers at the
  attribute level Ch. 18 asks for, not just by product name), and
  `stockByCategory` (Ch. 18's own "Categories" ask — reuses the
  existing `category` column every vertical already has, grouped and
  counted, not a new clothing-only concept).
- **Deliberately not built**: a Returns KPI/flow. There is no
  returns/refunds table or column anywhere in this codebase (confirmed
  by grep — `sales`/`sale_items` have no status/reversal concept at
  all, unlike Restaurant's `restaurant_orders.status` which does
  support `cancelled`). Per Ch. 21, this was left out rather than
  fabricated. A `product_returns` table, or a `sales.status` column
  with a `'returned'` value plus a reversing entry in `sale_items`,
  would be the natural next migration if Returns is prioritized later
  — flagged here rather than half-built.
- Mounted at `/clothing`: `GET /dashboard` only, same thin-router shape
  as Pharmacy/Supérette.
- 1 AI tool: `get_clothing_dashboard` (calls
  `clothing.service.getDashboard`), registered in
  `TOOL_IMPLEMENTATIONS`/`TOOL_DEFINITIONS`, automatically covered by
  `ai_tools_isolation.test.js`'s `test.each` loop (verified: 22/22
  AI-tool isolation tests pass, including this new one — 37/37 across
  the full Jest suite).
- Flutter: `lib/features/clothing/{data,domain,presentation}` — a
  repository, `ClothingDashboardStats`/`ClothingLowStockProduct`
  (with a computed `attributeSummary` getter that builds a "Size M ·
  Blue · Nike"-style tag from whichever of size/color/brand are
  actually set — none are required per product)/`ClothingBestSeller`/
  `ClothingCategoryStock`/`ClothingDebtor` models, and exactly ONE
  screen: `ClothingMainDashboardScreen`. Same `GradientHero`/
  overlapping-KPI-card/`AnimatedCounter`/`FadeSlideIn` chrome as every
  other vertical. Top KPI row: Today's Revenue / Today's Profit (net) /
  Transactions — identical to Pharmacy's/Supérette's. Second row: Low
  Stock count / Customer debt (total) / Stock value (retail). Body: a
  Stock Alerts card (Supérette's, with an added size/color/brand tag
  line), a NEW Stock-by-Category breakdown card (Ch. 18's own ask), a
  Customer Debt card (same as Supérette's, file-private duplicate per
  this codebase's existing per-vertical-file convention), and quick
  actions opening the existing CORE `ProductsListScreen`/
  `SuppliersScreen`.
- `main_shell.dart`: added ONLY a `'clothing'` arm to
  `_dashboardTabFor`. `_middleTabsFor`, `_middleNavItemsFor`, and
  `_MoreMenu._items` were intentionally left untouched, exactly like
  Pharmacy/Supérette — CORE's Sales/Inventory tabs and full More menu
  already fit.

**Not done as part of this**: Returns (see above — no ledger exists to
build it honestly on). No Size/Color/Brand input fields added to the
existing CORE "Add/Edit Product" form yet — the API accepts them
(`POST`/`PATCH /products`), but no Flutter screen's form has size/
color/brand text fields wired up, so today they can only be set via a
direct API call, not through the app's own UI. This is a real,
flagged gap — the next natural follow-up before this vertical can be
called complete end-to-end. No dedicated Stock-by-Category or Customer
Debt full-list screens (same "top-N preview only" gap as Supérette).
No dedicated `clothing.repository.js` isolation test yet (§4's gap,
same as every other vertical).

## 10. Restaurant vertical (Ch. 17) — added in this batch

Second fully-implemented specialized vertical, built strictly by
following §3's pattern against Clinic as the template:

- Migration `019_create_restaurant_tables.sql` — `restaurant_tables`,
  `restaurant_menu_items`, `restaurant_orders`, `restaurant_order_items`
  (name/price snapshotted per line, so a later menu price edit never
  rewrites a past order), `restaurant_reservations`, and an append-only
  `restaurant_payments` ledger — same shape as `clinic_payments`, same
  rule: revenue is always summed from the ledger by `paid_at`, never
  computed from `restaurant_orders.total_amount` directly, and never
  treated as a product sale (Ch. 17.7's explicit requirement).
- `backend/src/modules/restaurant/` — the standard 5 files. Tables,
  menu items, orders (with resolved line items pulling current
  menu price/name, or a free-form line), order status transitions
  (pending → preparing → ready → served → completed/cancelled, which
  also frees the table once no active order remains on it),
  payments/refunds, reservations, and a `getDashboard` aggregate:
  today/week/month revenue from the payments ledger, today's expenses
  (reusing the generic `expenses` module, exactly like Clinic), profit
  = revenue − expenses, outstanding payments, and best-selling dishes
  (grouped by item name so it survives a deleted menu item).
- Mounted at `/restaurant` in `routes/index.js`.
- 3 AI tools — `get_restaurant_dashboard` (calls the same
  `restaurant.service.getDashboard` the dashboard screen calls, so the
  assistant's numbers always match the UI, per Ch. 21),
  `get_restaurant_tables_status`, `get_restaurant_active_orders` —
  registered in both `TOOL_IMPLEMENTATIONS` and `TOOL_DEFINITIONS`,
  automatically covered by `ai_tools_isolation.test.js`'s `test.each`
  loop.
- Flutter: `lib/features/restaurant/{data,domain,presentation}` — a
  repository, models (`RestaurantTable`, `RestaurantMenuItem`,
  `RestaurantOrder`/`RestaurantOrderItem`, `RestaurantReservation`,
  `RestaurantDashboardStats`), and 5 screens:
  - `RestaurantMainDashboardScreen` (tab 0) — reuses the exact same
    `GradientHero`/overlapping-KPI-card/`AnimatedCounter`/`FadeSlideIn`
    chrome as `ClinicMainDashboardScreen` (itself matching the generic
    `DashboardScreen`). Top KPI row: Today's Orders / Active Orders /
    Today's Revenue (never a product-sale figure). Second row: Tables
    Occupied, Reservations Today, Outstanding Payments. Body: an active
    orders snapshot (kitchen/table status, Ch. 17's "Kitchen/order
    status") instead of a sales trend chart, and restaurant quick
    actions (New Order, Tables, Menu, Reservations) instead of
    "New Sale"/"Scan Invoice".
  - `RestaurantOrdersScreen` (tab 1) — the orders board: every still-
    open order today, one tap to advance it to its next kitchen stage,
    a bottom sheet to create a new order against the menu and an
    optional table.
  - `RestaurantTablesScreen` (tab 2) — a floor-plan-style grid of
    tables; tapping one cycles its status (available → occupied →
    cleaning → available).
  - `RestaurantMenuScreen` (More menu) — add/toggle-availability/delete
    menu items, grouped implicitly by category.
  - `RestaurantReservationsScreen` (More menu) — upcoming reservations
    with a quick status menu (confirm/seat/cancel/no-show).
- `main_shell.dart`: added the `'restaurant'` arm to
  `_dashboardTabFor`, `_middleTabsFor` (Orders/Tables replace
  Sales/Inventory), `_middleNavItemsFor`, and `_MoreMenu._items`
  (Menu/Reservations replace the dropped retail-only items) — the
  `clinic` arms and the CORE default are untouched.
- One incidental fix made along the way: `core/network/api_client.dart`
  had `get`/`post`/`put`/`delete` but no `patch`, even though this
  backend already declares PATCH routes (Clinic's own
  `PATCH /clinic/appointments/:id/status`, previously unused by any
  Flutter call site). Added `ApiClient.patch()` — purely additive, no
  existing call site touched — and used it for Restaurant's table/
  order-status/menu-availability/reservation-status updates instead of
  reusing `put()` as a workaround.

**Not done as part of this**: see §8's Restaurant-specific bullets
(partial refunds, kitchen-printer integration, linear-only order-stage
advancement, single-tap table-status cycling instead of a full picker).
No dedicated `restaurant.repository.js` isolation test yet (§4's gap,
same as Clinic's). Menu/Reservations screen labels are hardcoded
English (§3.7's pragmatic call, same as Customers/Suppliers already
were).

## 9. Consultation Payments (Ch. 7-11) — added in this batch

The one functional gap Clinic actually had at "reference vertical"
status: there was no price, no paid amount, no payment status, and no
revenue/profit anywhere in the Clinic dashboard. Fixed end-to-end:

- Migration `018_add_clinic_consultation_payments.sql` — adds
  `consultation_price` / `amount_paid` / `payment_status` to
  `clinic_visits`, plus an append-only `clinic_payments` ledger table
  (a negative amount is a refund). Same tenant-isolation rule as every
  other clinic table: `company_id` on every row, never derived only
  via a JOIN.
- `clinic.repository.js` / `clinic.service.js` — `recordPayment`,
  `refundVisit`, `revenueForRange`, `outstandingTotal`. Revenue is
  summed from the ledger by `paid_at` (the day money actually moved),
  not `visited_at`, so a payment collected today toward an older visit
  correctly counts as today's revenue.
- `GET /clinic/dashboard` now also returns `todayRevenue`,
  `weekRevenue`, `monthRevenue`, `todayExpenses` (reusing the existing
  generic `expenses` module — rent/electricity/salaries/supplies are
  ordinary expense categories, not a clinic-only concept), `todayProfit`
  (= revenue - expenses, per Ch. 11 exactly), and `outstandingPayments`.
- New endpoints: `POST /clinic/visits/:id/payments` (record a full or
  partial payment) and `POST /clinic/visits/:id/refund`.
- `getPatientProfile` now also returns `payments` and
  `outstandingBalance` per patient (Ch. 5).
- `get_clinic_dashboard`'s AI tool now calls `clinic.service.getDashboard`
  instead of `clinic.repository.dashboardStats` directly, so the AI
  assistant can answer revenue/profit questions with the exact same
  numbers the dashboard shows (Ch. 21's single-source-of-truth rule).
- Flutter: `ClinicDashboardScreen` gained a second KPI row (Today's
  Revenue / Today's Profit / Outstanding Payments) using the same
  `_StatCard` visual language, just for money. `ClinicQueueScreen`'s
  "Complete Consultation" action now opens a small dialog to capture
  the consultation price and (optionally) an on-the-spot payment
  instead of silently defaulting both to zero. `ClinicPatientProfileScreen`
  now shows a payment-status badge and price/paid amounts per visit,
  an outstanding-balance line when the patient owes something, and a
  "Record Payment" button on any visit that still has a balance.
- Also fixed while in this area: `clinic_repository.dart` (Flutter)
  had a broken import (`'clinic_models.dart'` instead of
  `'../domain/clinic_models.dart'`) that would have failed at compile
  time — unrelated to payments, just found along the way.

**Not done as part of this**: refunds are always full refunds (no
partial-refund amount input yet); no payments list/history screen of
its own (the ledger exists and is queryable via `findPaymentsByPatient`,
just not yet rendered as its own screen). **Update (§6):** the main
Dashboard tab's clinic quick actions now include a "Record Payment"
button, but it only navigates to the Patients list — the user still
has to open a patient's profile and pick the specific visit with a
balance before actually recording anything. A true one-tap "record a
payment against any outstanding visit" flow straight from the
Dashboard is still not built.

## 14. Enterprise / Company vertical (Ch. 19) — added in a later batch

Sixth and last of the requested verticals. Maps from `business_type =
'company'` (the value the onboarding screen already sends for
"Company").

- **One additive migration**, `021_create_enterprise_projects.sql` —
  `enterprise_projects` (+ `enterprise_project_status_enum`:
  planned / active / on_hold / completed / cancelled). Projects is the
  only Ch. 19 concept with no home in the existing schema (§8 flagged
  this). Everything else Ch. 19 lists (Clients = `customers`,
  Employees/Salaries, Suppliers, Invoices, Payments, Expenses) is CORE
  data reused as-is. `company_id` is on the row itself; `customer_id`
  optionally links a project to a client and is checked against the
  caller's own company before insert.
- `backend/src/modules/enterprise/` — the standard 5 files plus
  `__tests__/enterprise.test.js`. Mounted at `/enterprise`:
  `GET /dashboard`, `GET /projects[?status=]`, `POST /projects`,
  `PATCH /projects/:id/status`.
- **Financial formula (Ch. 21 single source of truth)** — deliberately
  identical to the CORE dashboard (`dashboard.routes.js`), built from
  the same repository functions rather than new SQL:
  `revenue = sales.total + credit payments received`,
  `expenses = prorated operating expenses + employee salary cost`,
  `netProfit = revenue - expenses`. Payroll is also returned on its own
  (`monthPayroll`) because Ch. 19 lists Salaries separately; it is
  already inside `expenses`, not additional to it.
  "Outstanding invoices" = invoices with `status = 'unpaid'`, amount
  from the linked sale's total; client credit balances
  (`customers.balance_due`) are reported separately since credit sales
  live in their own tables.
- 1 AI tool, `get_enterprise_dashboard` (calls
  `enterprise.service.getDashboard`), registered in both maps and covered
  by `ai_tools_isolation.test.js`'s `test.each` loop.
- Flutter: `lib/features/enterprise/{data,domain,presentation}` —
  `EnterpriseMainDashboardScreen` (same GradientHero / overlapping KPI
  row / FadeSlideIn chrome as every other vertical; hero KPIs are this
  MONTH's Revenue / Net profit / Unpaid invoices, since a company's
  invoicing is lumpy and "today" would often read zero) and
  `EnterpriseProjectsScreen` (list, add sheet with optional client
  picker, status menu). `main_shell.dart` gained ONLY the `'company'`
  arm of `_dashboardTabFor`; tabs and More menu keep the CORE default,
  like Pharmacy/Supérette/Clothing.

**Not done as part of this**: no project edit/delete (create + status
change only); no per-project cost/invoice linkage (a project's `budget`
is informational — invoices are not tied to projects); no dedicated
`enterprise.repository.js` isolation test beyond the new unit test's
`$1 = companyId` assertions; the CORE Sales/Inventory tabs still appear
for a company account (retail-flavored, but left alone per the "only
add arms where a vertical diverges" rule — revisit if that feels wrong
for company users); labels are hardcoded English (§3.7).

### Known inconsistency found while building this (pre-existing)

`dashboard.routes.js` was later changed to fold **credit payments** into
revenue and **salary cost** into expenses, but the Pharmacy, Supérette
and Clothing services still compute `todayNetProfit` as
`sales revenue - operating expenses` only (their doc comments still say
"matching the CORE dashboard"). So those three verticals' "Today's
Profit" can differ from the CORE dashboard's for the same day whenever a
company has payroll or credit repayments. Enterprise uses the CORE
formula; aligning the other three (ideally via one shared function) is
a recommended follow-up, not done here to keep this batch's diff
additive.
