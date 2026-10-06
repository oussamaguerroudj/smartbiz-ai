# Modiri — Business Type Correction (Phase 4.1)

**What this was:** the prior "Dashboard-family simplification" pass
(`backend/SPECIALIZED_MODULES.md` §15) reduced the onboarding Business
Type picker from 24 tiles to 5, and dropped `company` (Enterprise) along
with the verticals that have no dashboard at all — even though Enterprise
has always had a real, fully-built one (`EnterpriseMainDashboardScreen`).
That was a mistake. This pass reverses only that one part of it.

**Environment note, same as the prior audit pass:** no Flutter/Dart SDK,
no emulator/device, no backend network access. Every change below is a
real source-level edit, cross-checked as thoroughly as static inspection
allows (JSON validity, 1:1 getter/key matching across all 4 generated
localization files, brace/paren/bracket balance, grep-based call-site
checks) but **none of it has been compiled or run**.

---

## FIXED

### Business Type picker now shows 6 families, not 5
- **Root cause:** `kSelectableBusinessTypes` in `business_type_screen.dart`
  listed `grocery`, `clothing`, `restaurant`, `clinic`, `pharmacy` only.
  `company` was left out, so new users could never select Enterprise even
  though `main_shell.dart` (`'company' => EnterpriseMainDashboardScreen()`),
  the `company` DB enum value, and the Enterprise backend module
  (`backend/src/modules/enterprise/`) were all still fully intact and
  working for existing accounts.
- **Fix implemented:** added `BusinessType.company` back to
  `kSelectableBusinessTypes` as the 6th entry, after Pharmacy. Nothing
  else in the enum, `apiValue`/`fromApiValue` mapping, icon, or routing
  was touched — this was purely restoring the one missing picker entry.
- **Label change:** the picker tile's label for `company` changed from
  plain "Company" to **"Enterprise / Company"**, matching the
  `"X / Y"` framing already used for the other merged families
  ("Market / Store", "Restaurant / Café", "Clinic / Medical") and your
  requested final naming. Updated in all 4 places a Dart string lives for
  this key: the English fallback `label` getter, the 3 `.arb` source
  files (`businessTypeCompany`), and the 4 generated
  `app_localizations_*.dart` files (hand-edited, since `flutter
  gen-l10n` can't run in this sandbox — exactly as the prior audit pass
  did for its own localization fixes). No new key was added; the
  existing `businessTypeCompany` / `businessTypeCompanyDesc` keys were
  reused, so nothing else that references them needed to change.
  - EN: "Enterprise / Company"
  - AR: "مؤسسة / شركة"
  - FR: "Entreprise / Société"
- **Description:** left as-is ("Employees, invoices" / matching AR/FR) —
  still accurate, not part of what you asked to change.
- **Documentation corrected:** `backend/SPECIALIZED_MODULES.md` §15
  rewritten to say 6 families (not 5), and to stop listing `company` as
  "removed from the picker" — it now explains the Phase 4.1 correction
  and that the routing/DB/backend side was never touched by either the
  original mistake or this fix.
- **Files changed:**
  `mobile/lib/features/auth/presentation/screens/business_type_screen.dart`,
  `mobile/lib/core/localization/app_{en,ar,fr}.arb`,
  `mobile/lib/l10n/app_localizations_{en,ar,fr}.dart`,
  `backend/SPECIALIZED_MODULES.md`.
- **Files deliberately NOT changed:** anything backend (`companies.routes.js`'s
  `VALID_TYPES`, `business_type_enum`, migrations), `main_shell.dart`,
  `enterprise/` (mobile or backend) — all of it already worked correctly
  for `company` before this fix and needed no correction.

---

## VERIFIED (checked, no fix needed)
- **`company` still routes to the Enterprise dashboard:** confirmed
  `main_shell.dart` line 93, `'company' => const
  EnterpriseMainDashboardScreen()`, is untouched by this pass (grep shows
  exactly one match, unchanged).
- **Existing Enterprise accounts are unaffected:** nothing under
  `backend/src/modules/enterprise/`, `backend/migrations/`
  (`021_create_enterprise_projects.sql` untouched), or the `company`
  DB enum label was touched. `company` was never removed at the database
  level by the original simplification pass either (it only changed the
  Flutter picker), so there was nothing to restore on that side.
- **No `requireBusinessType()` gate blocks Enterprise:** checked
  `backend/src/modules/enterprise/enterprise.routes.js` — it has no
  business-type gate at all (unlike clinic/restaurant), so this fix
  didn't need to touch any middleware allow-list.
- **Localization — EN/AR/FR:**
  - All 3 `.arb` files still parse as valid JSON, still have exactly
    502 keys each (no keys added or removed — only the value of
    `businessTypeCompany` changed).
  - All 4 generated files (`app_localizations.dart` abstract class +
    `_en`/`_ar`/`_fr`) still declare exactly the same 466-member
    getter/method set as each other, with zero diff — confirmed by
    scripted comparison, not eyeballing.
- **No broken references:** grepped the whole repo for stale mentions of
  "5 dashboard families" / "5 canonical" / "these 5" — none left outside
  this report's own explanation of the history. Grepped
  `mobile/REDESIGN_CHANGELOG.md` and `backend/ERD.md` for
  company/enterprise mentions — none referenced the picker or needed
  updating.
- **Brace/paren/bracket balance:** zero net imbalance in every file this
  pass edited (`business_type_screen.dart` and the 3 generated
  localization files), scripted check.

## REMAINING (not fixed, out of scope for this correction)
- Same items already flagged as REMAINING in `FINAL_AUDIT_REPORT.md`
  (full project-wide audit, `description` field for products, clearing
  an expiration date via Edit Product, size/color/brand/expiration not
  shown in the product list view) — untouched by this pass, still open.

## BUILD STATUS
- **Flutter analyze:** NOT RUN — no Flutter SDK in this environment.
- **Flutter build APK:** NOT RUN — no Flutter SDK in this environment.
- **Backend:** NOT RUN — no network/database access in this environment
  (also not touched by this pass, so nothing new to run here).
- **Real device test:** NOT RUN — no Android device/emulator.

**What I'd suggest:** `flutter pub get && flutter gen-l10n && flutter
analyze` locally — `flutter gen-l10n` will regenerate the localization
files from the now-updated `.arb` sources (safe, same key set as
before), and `flutter analyze` will confirm the picker compiles and
shows all 6 tiles. Then run through onboarding once and confirm
"Enterprise / Company" appears as the 6th option and still lands on the
existing Enterprise dashboard after signup.
