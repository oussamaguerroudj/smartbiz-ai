# Modiri — Final Audit + Bug-Fix Pass (Phase 2 + Phase 3)

**Environment note, upfront:** this pass was done in a sandbox with no Flutter/Dart SDK,
no Android device/emulator, and no network access to run the backend. Every fix below
is a real source-level change, cross-checked as thoroughly as static inspection allows
(bracket/paren balance, JSON validity, 1:1 key/getter matching, grep-based call-site
verification), but **none of it has been compiled or run**. See BUILD STATUS at the end
for exactly what that means for you.

---

## FIXED

### 1. Finding D — duplicate localization keys (compile-blocking)
- **Root cause:** `amountDzdLabel`, `quantityLabel`, and `recordPaymentAction` were
  declared twice in all three `.arb` source files; `periodDaily`/`periodMonthly`/
  `periodYearly` were declared twice only in the hand-edited generated Dart files (not
  in the `.arb`). A Dart class cannot have two members with the same name, so the app
  would not compile.
- **Fix implemented:**
  - `amountDzdLabel`, `quantityLabel`: identical text both times → deduplicated to one
    entry.
  - `periodDaily`/`periodMonthly`/`periodYearly`: **not** identical, contrary to the
    Phase 3 report's assumption — the French copies differed in grammatical gender
    ("Quotidien/Mensuel/Annuel" vs "Journalière/Mensuelle/Annuelle"). Kept the version
    matching the `.arb` source of truth and fixed a missing accent
    (`Journaliere` → `Journalière`) along the way.
  - `recordPaymentAction`: genuinely different AR/FR wording for two different
    contexts, confirmed by the surrounding UI text at each call site. Split into
    `restaurantRecordPaymentAction` ("تسجيل الدفع" / "Enregistrer le paiement" — used
    in `restaurant_order_detail_screen.dart`, paying off one order) and
    `clinicRecordPaymentAction` ("تسجيل دفعة" / "Enregistrer un paiement" — used in
    `clinic_main_dashboard_screen.dart` and `clinic_patient_profile_screen.dart`,
    recording a payment against an ongoing balance). **This context mapping is my
    inference from the surrounding UI, not a guess dressed up as certainty — please
    confirm the AR/FR wording reads correctly once you see it running.**
- **Files changed:** `mobile/lib/core/localization/app_{en,ar,fr}.arb`,
  `mobile/lib/l10n/app_localizations.dart`,
  `mobile/lib/l10n/app_localizations_{en,ar,fr}.dart`,
  `mobile/lib/features/restaurant/presentation/screens/restaurant_order_detail_screen.dart`,
  `mobile/lib/features/clinic/presentation/screens/clinic_main_dashboard_screen.dart`,
  `mobile/lib/features/clinic/presentation/screens/clinic_patient_profile_screen.dart`.
- **How it was tested:** scripted verification — (a) every `.arb` file parses as valid
  JSON with zero duplicate top-level keys; (b) the set of getters/methods in the
  abstract `AppLocalizations` class exactly equals the set of keys in the `.arb`
  source, with zero missing and zero extra members; (c) all three locale
  implementations (`_en`/`_ar`/`_fr`) declare exactly the same member set as the
  abstract class and each other; (d) zero duplicate getter names in any of the 4
  generated files; (e) `grep` confirms no remaining reference to the old
  `recordPaymentAction` name anywhere in `lib/`.
- **Test result:** PASS (static verification). Not compiled.

### 2. Android back navigation (`main_shell.dart`)
- **Root cause:** the app's navigation is a single root Navigator (MaterialApp's own —
  `MainShell` declares no Navigator of its own) plus an `IndexedStack` that keeps all 4
  tabs alive without ever pushing/popping a route on tab switch. The `main` phase
  itself is never pushed either: `main.dart`'s `_AppFlow` swaps
  Login/Onboarding/MainShell via `AnimatedSwitcher` + `setState`, not
  `Navigator.push`. With no `PopScope`/`WillPopScope` anywhere in the codebase,
  pressing back while on a non-Dashboard tab (nothing else pushed) had nothing to pop
  and fell through to Android's default behavior — closing the app immediately,
  regardless of which tab the user was on.
- **Fix implemented:** added `PopScope` at the `MainShell` level. If the current tab
  index isn't Dashboard (0), back now switches to Dashboard instead of exiting. From
  Dashboard itself, back is left alone (`canPop: true`) so normal platform behavior
  still applies.
- **On the "or old stack"/"Login/Onboarding" part of the finding:** I could not find a
  code path, under this architecture, where the back button can pop into
  Login/Onboarding — `_AppFlow` is never pushed as a route, so there's nothing to pop
  back to there. If you're still seeing that specific symptom after this fix, it's
  more likely coming from the `ref.listen` on `sessionProvider` in `main.dart` (which
  deliberately jumps to the login phase on session/token expiry) than from the back
  button itself — worth checking whether it coincides with a 401 rather than a
  back-press.
- **Files changed:** `mobile/lib/features/shell/presentation/main_shell.dart`.
- **How it was tested:** read the full navigation architecture (`main.dart`,
  `main_shell.dart`, and every `Navigator.of(context).push*`/`pop*` call in the
  codebase) to confirm the root-cause analysis; verified brace/paren balance.
  **Not run on a device** — please verify the actual back-button feel once built.
- **Test result:** Implemented, not device-tested.

### 3. Pharmacy — expiration date (manual creation + AI Scan)
- **Backend:** already fully wired end-to-end (schema column, repository
  create/update, service, controller all pass `expirationDate` through) — no backend
  change was needed.
- **Mobile — manual creation (`add_product_screen.dart`):** added an expiration-date
  picker, shown only for pharmacy accounts (checked via `companyInfoProvider`), wired
  into `ProductsRepository.addProduct`.
- **Mobile — AI Scan (`ai_scanner_screen.dart`):** added an `expirationDate` field to
  `ScannedItem` and an expiration-date picker to the stock-review card, shown only for
  pharmacy accounts. A receipt/invoice scan can't OCR a date that isn't printed on it,
  so — consistent with how quantity and purchase price already work on that same
  card — it's a user-entered field the reviewer fills in before confirming, not
  something extracted automatically.
- **Files changed:** `mobile/lib/features/products/presentation/screens/add_product_screen.dart`,
  `mobile/lib/features/ai/presentation/screens/ai_scanner_screen.dart`,
  `mobile/lib/features/products/data/products_repository.dart`,
  `mobile/lib/features/products/domain/product.dart`.
- **How it was tested:** traced the full field path
  UI → repository → HTTP body key (`expirationDate`, `YYYY-MM-DD` string) →
  `products.controller.js` → `products.service.js` → `products.repository.js` →
  `products` table `expiration_date` column, confirming every hop uses matching
  key names. Not run.
- **Test result:** Implemented, not run.
- **Also verified (no fix needed):** Pharmacy Dashboard's "Expiring Soon" is genuine —
  it calls a real `GET /pharmacy/expiring-products` endpoint backed by a real SQL
  query against `expiration_date` (`pharmacy.repository.js`), not mock data. This was
  a Phase 3 report claim; I independently re-checked it and it holds up.

### 4. Clothing — size / color / brand (manual creation + AI Scan)
- **Backend:** already fully wired end-to-end (migration `020_add_clothing_attributes.sql`,
  repository create/update, service, controller) — no backend change needed.
- **Mobile — manual creation:** added Size/Color/Brand fields to `add_product_screen.dart`,
  shown only for clothing accounts, wired into `ProductsRepository.addProduct`.
- **Mobile — AI Scan:** added `size`/`color`/`brand` to `ScannedItem` and matching
  fields to the stock-review card, shown only for clothing accounts, same
  user-entered rationale as the expiration date above.
- **Mobile — display:** `Product` model now carries `size`/`color`/`brand` from
  `GET /products` responses, and `ProductDetailsScreen` now shows them when present
  (previously nothing on the read side surfaced these at all).
- **Files changed:** same list as item 3 above.
- **How it was tested:** same field-path trace as item 3, confirming
  `size`/`color`/`brand` keys match the `products` table columns end to end. Not run.
- **Test result:** Implemented, not run.

### 5. Product Editing — real Edit Product screen
- **Root cause:** only the product photo could be changed from the app
  (`ProductDetailsScreen._ProductPhoto`); every other field required going around the
  app entirely. The backend's `PUT /products/:id` already supported a full partial
  update for every column via `COALESCE` — it just was never called with anything but
  `imageUrl`.
- **Fix implemented:** new `EditProductScreen`, reachable via an Edit button on
  `ProductDetailsScreen`'s app bar, pre-filled from the existing product. Deliberately
  mirrors `AddProductScreen`'s field set, order, labels and validators so editing feels
  like the same form, per the "don't change existing UI/UX unless necessary" rule.
  Covers name, category, barcode, purchase price, selling price, quantity, and
  (conditionally) expiration date / size / color / brand. Added the generic
  `ProductsRepository.updateProduct()` method this screen calls.
  - `description` was **not** added — there is no `description` column anywhere in
    the current backend schema or `Product` model. Adding one would mean a new
    migration + column + full round-trip, which is a bigger, riskier change than this
    pass's "minimal, safe" scope calls for. Flagged under REMAINING below in case you
    want it as a separate, deliberate follow-up.
- **Known limitation:** clearing an already-set expiration date via the Edit screen
  doesn't currently propagate — `updateProduct` only sends a field when it's non-null,
  so passing `null` (to mean "clear it") is indistinguishable from "leave unchanged."
  Clearing barcode/category/size/color/brand does work correctly (empty string is
  sent and is a real, non-null value). Flagged under REMAINING.
- **Files changed:** new `mobile/lib/features/products/presentation/screens/edit_product_screen.dart`;
  edited `mobile/lib/features/products/presentation/screens/product_details_screen.dart`,
  `mobile/lib/features/products/data/products_repository.dart`.
- **How it was tested:** traced the same field-path as items 3–4 for every editable
  column; verified brace/paren balance; verified no other code constructs `Product(...)`
  in a way the new optional fields would break. Not run.
- **Test result:** Implemented, not run.

---

## VERIFIED (checked, no fix needed)
- Restaurant shell labels, Superette/Clothing/Pharmacy dashboard localization
  (Phase 3's claim): re-checked with a fresh grep pass for hardcoded
  `Text('...')` string literals in all three dashboard files — found none.
- All 466 localization keys (up from 456 pre-fix, +10 for the new pharmacy/clothing/
  edit-product labels) are present in every one of the 3 `.arb` files and all 4
  generated Dart files, with zero duplicates and zero mismatches, after every change
  in this pass.
- Backend `products` schema/repository/service/controller already fully support
  `expiration_date`, `size`, `color`, `brand` on both create and update — confirmed
  by reading the actual SQL and JS, not assumed.
- Pharmacy Dashboard "Expiring Soon" uses a real backend endpoint and real data (see
  item 3 above).
- Clothing Dashboard repository/screen: no `TODO`/mock/`Random()` markers found on a
  targeted grep pass (did not read every line).

## REMAINING (not fixed, with real reasons)
- **Full project-wide audit** (the 20+ category list — compilation errors, missing
  loading/error/empty states, broken CRUD flows across every module, overflow issues,
  incorrect dashboard calculations elsewhere, AI scan integration beyond what's
  covered above, permissions/auth issues, null handling, etc.) was **not done
  exhaustively**. I checked the specific items you named and the modules they touch;
  I did not review every screen in the app. This is a genuinely large undertaking —
  doing it honestly (not just skimming for keywords) needs either much more time here
  or, better, an environment that can actually run `flutter analyze` to surface real
  issues instead of me guessing at them from reading.
- **`description` field for products** — not added; see item 5 above for why.
- **Clearing an expiration date via Edit Product** doesn't currently work (see item 5).
- **Product list screen** doesn't yet surface size/color/brand/expiration in the list
  view itself (only in Product Details) — not requested explicitly, noting it in case
  you want it.

## BUILD STATUS
- **Flutter analyze:** NOT RUN — no Flutter SDK in this environment.
- **Flutter build APK:** NOT RUN — no Flutter SDK in this environment.
- **Backend:** NOT RUN — no network/database access in this environment.
- **Real device test:** NOT RUN — no Android device/emulator in this environment.

**What I'd suggest:** pull this zip, run `flutter pub get && flutter gen-l10n &&
flutter analyze` locally exactly as Phase 3 already asked you to — `flutter
gen-l10n` will regenerate the localization files from the now-clean `.arb` sources
(safe now, since there are no duplicate keys left to collide), and `flutter analyze`
will tell you definitively whether anything in this pass has a real compile error I
couldn't see from static reading alone. If you have Claude Code available locally
with the Flutter SDK and a device, it can run that whole loop — analyze, build,
install, and fix — directly, which this sandbox can't do.
