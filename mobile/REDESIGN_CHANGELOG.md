# Modiri AI — Design System v2 ("Indigo") — What Changed

This applies the approved Modiri AI visual redesign to your real Flutter
app. Every screen still talks to the same repositories/providers/API —
only presentation changed. No business logic, validation, or navigation
behavior was altered.

## 1. Setup

```bash
flutter pub get
```

That's it — `google_fonts` was added to `pubspec.yaml` so Space Grotesk /
Plus Jakarta Sans actually render (the old `fontFamily: 'Inter'` string
was silently falling back to the platform default before).

## 2. Design tokens (cascades to ~all 40 screens)

- `lib/core/theme/app_colors.dart` — old emerald palette → new indigo/blue
  brand palette. Same token names (`AppColors.primary`, `.danger`, etc.),
  so nothing else needed to change to pick up the new brand color.
- `lib/core/theme/app_typography.dart` — now uses `google_fonts`
  (Space Grotesk for headings/numbers, Plus Jakarta Sans for body).
- `lib/core/theme/app_spacing.dart` — rounder corners, new shadow tokens
  (`AppSpacing.cardElevation`, `.brandGlow`).
- `lib/core/theme/app_theme.dart` — buttons, inputs, chips, segmented
  controls, bottom nav, and page transitions all restyled here.

Because every screen already followed the "never hardcode colors, always
use AppColors/Theme.of(context)" convention, these four files alone
reskin most of the app.

## 3. Mechanical shadow-card sweep

19 occurrences across 18 files shared the exact same bordered-container
pattern. A scripted pass converted every one of them from a hairline
border to a soft floating shadow (`AppSpacing.cardElevation`) — matching
the redesign's "cards float, they don't sit in a box" look — without
hand-editing each screen.

## 4. New reusable widgets (`lib/core/widgets/`)

| Widget | Used for |
|---|---|
| `AnimatedCounter` | Count-up numbers for KPIs / totals |
| `MiniBarChart` | Bars that grow in, driven by real data |
| `StatusPill` | Rounded status badges, optional pulsing dot |
| `GradientHero` / `BreathingIcon` | The indigo hero gradient + breathing logo |
| `FadeSlideIn` / `.staggered()` | Entrance animation for screens & lists |
| `PillBottomNav` | Floating rounded bottom nav bar |

## 5. Screens rewritten in full

Splash, Onboarding, Login, Main Shell (nav + More menu), Dashboard,
Reports, AI Assistant.

**Dashboard note:** the mockup's "sales trend" chart was dropped rather
than faked — `GET /dashboard` only returns today's totals, not a
day-by-day series. Reports got a real bar chart instead, built from
`topProducts` unit counts, which the backend does return.

**AI Assistant note:** answers are still computed instantly from real
repository data (unchanged); a short, fixed 550ms pause plus a typing
indicator was added purely for feel — it never changes what's said.

## 6. Screens polished in place

Employees, Appointments, Invoices, Expenses, Products list, Sales list,
Settings, Business Type — added `StatusPill`/icon chips/staggered entrance
using real fields already in each domain model. Nothing invented: e.g.
the Employees list shows real `baseSalary` rather than the mockup's
fabricated "Present/Absent" (the list endpoint has no attendance field).

## 7. Everything else

Customers, Suppliers, Notifications, Employee/Product details, Create
Sale — untouched individually but already look different from the theme
+ shadow-card sweep (colors, fonts, buttons, card shadows).

## Not done (flag if you want it)

- Products list / Add Product / Create Sale screens weren't given the
  full bespoke treatment (staggered lists only) — happy to take them
  further.
- No automated test run — this environment has no Flutter SDK, so
  changes were verified by careful review + static brace/import checks,
  not `flutter analyze`/`flutter run`. Please run `flutter pub get` and
  `flutter analyze` before shipping.

---

## Correction pass — pixel-accuracy fixes + rebrand + video splash

A follow-up pass against the reference HTML (`smartbiz_ai_redesign.html`),
scoped strictly to fixing differences, not adding features.

### Rebrand
Every occurrence of "SmartBiz AI" replaced with "Modiri AI" — app title,
`ModiriApp` class (was `SmartBizApp`), pubspec `name`/`description`,
`.arb` localization files, splash text, and every doc comment. Verified
zero remaining matches for `SmartBiz`/`smartbiz` anywhere in `mobile/`.

### Video splash
New `VideoSplashScreen` (`features/onboarding/.../video_splash_screen.dart`)
plays `assets/video/splash.mp4` full-screen with **zero playback
controls**, autoplay, and calls back the moment the video ends. If the
video fails to initialize, it falls back to the existing branded
`SplashScreen` (gradient + breathing logo) instead of a blank screen. A
10-second safety timer guarantees the app always continues past splash
even if something hangs. `main.dart`'s phase switch is now wrapped in an
`AnimatedSwitcher` so *every* phase change (not just splash) cross-fades
instead of cutting abruptly.

### Chart accuracy
`MiniBarChart` rewritten to match the reference `.bars`/`.bars i` CSS
exactly: fixed `linear-gradient(#8fa0fb → #3d55f5)` fill (not a computed
tint), 5px gap, 44px height, 5/5/2/2px corner rounding, and — importantly —
**per-bar staggered animation** (90ms delay × index, replaying whenever
the data changes) which was previously missing; all bars animated at once.

### Reports tabs
Replaced Material's `SegmentedButton` with a new `PillTabs` widget that
reproduces the reference's `.pill-tabs`/`.pill-indicator` exactly: same
track color/radius/padding, and a sliding indicator sized to each tab
label's actual width (not equal-width segments) — `SegmentedButton`
could not do this regardless of styling.

### Bottom navigation
`PillBottomNav` rewritten to match `.bottom-nav`/`.nav-item` exactly:
icon-only (no text label, no active-state highlight chip), opacity
0.5→1 + 2px lift on the active item, `rgba(16,20,58,.92)` background
with a real 6px backdrop blur, 18px corner radius.
**Trade-off, flagged rather than silently applied:** dropping labels
matches the HTML pixel-for-pixel, but four icon-only tabs are genuinely
harder to tell apart than labeled ones on a real device. Each item still
carries a semantic label for accessibility. Say the word if you'd
rather have labels back — that's one line to revert.

### FAB
New `AppFab` wrapper: plays the reference's `:hover{scale(1.08)
rotate(90deg)}` transform as a one-shot tap "bounce" (touch has no
hover, so tap is the faithful equivalent), and applies the exact
`rgba(61,85,245,.65)` brand-glow shadow instead of Material's default
grey elevation. Swapped in across all 7 screens that had a raw FAB
(Sales, Employees, Customers, Expenses, Products, Suppliers,
Appointments).

### Small precision fixes
- `StatusPill`'s presence-dot pulse now reproduces the reference's exact
  keyframes (spread 0→5→0px, alpha .45→0, 1.8s) instead of an
  approximated continuous formula.
- Onboarding dots: 16px/6px widths (was 20/6), 5px height, correct
  opacity values — matches `.dot-line` exactly.
- Design tokens tightened to the reference's literal CSS values:
  `radiusCard` 18→16, `radiusInput` 14→11, and both shadow tokens
  (`cardElevation`, `brandGlow`) now use the reference's exact
  color-alpha/blur/spread numbers instead of approximated ones.

### One deliberate non-change, explained (not silently skipped)
The reference HTML renders every screen inside a **236×486px mockup
phone frame** with 7–15px type — sizes chosen for a marketing tour page
thumbnail, not literal device pixels. Copying those numbers 1:1 into a
real ~390–430px-wide phone would make the app illegible. The original
redesign pass already made this scaling judgment call (real spacing/type
tokens, same color values, same proportions and corner-radius
*relationships*); this correction pass tightened the tokens that **are**
meaningfully comparable 1:1 (exact colors, shadow alpha/blur/spread,
animation durations/easing, gradient stops) without reintroducing
unusably tiny text.

### Still not verified by running the app
Same caveat as before: no Flutter SDK in this environment. All of the
above was checked by careful reading plus scripted brace/import/
duplicate-symbol checks, not `flutter analyze` or an emulator. Please
run `flutter pub get && flutter analyze` — and actually launch it once —
before shipping.

---

## Targeted bug-fix pass (no redesign, no rewrite)

Scoped strictly to the issues reported after real-device testing. Every
fix below is additive/corrective to the existing architecture — no
screens were redesigned, no repositories/providers/navigation were
replaced, and **`api_client.dart`'s base URL was not touched.**

### 1. Finish Setup not navigating to Dashboard
Root cause found: `main.dart`'s `_AppFlowState.build()` was mutating
`_phase` **directly inside build()** based on `session.isLoggedIn`, on
every single rebuild — a real anti-pattern. This could silently override
a just-set "go to Dashboard" transition (e.g. from `BusinessSetupScreen`'s
`onFinish`) if the session read as logged-out for any reason during that
rebuild. Fixed by switching to `ref.listen`, which now only reacts to an
actual logout **event** (was-logged-in → now-logged-out), never
re-derives phase from session state on every build.

Also hardened `business_setup_screen.dart` itself: the save/validate/
navigate flow was already structurally correct (validate → await the
real `PUT /companies/me` → only navigate after it succeeds → show an
error and stay put on failure) — this pass fixed a real bug in it (the
read-only "Business type" field built a brand-new `TextEditingController`
every rebuild without disposing the old one — a leak, and a source of
flaky state), added a double-submit guard, replaced the easy-to-miss
snackbar with a blocking error dialog, and added `debugPrint` logging of
the actual status code/message on failure.

**Honest caveat:** I don't have access to your live backend, so I can't
100% confirm this was *the* cause of what you saw. If it recurs after
this fix, the dialog + debugPrint will show you the actual HTTP
status/message from `PUT /companies/me` — check that first.

### 2. Create Account / Setup layout
Both `register_screen.dart` and `business_setup_screen.dart` were
audited against the reported overflow/clipping symptoms. Both already
use `SafeArea` + `SingleChildScrollView` + `Padding` + a stretched
`Column` (no hardcoded widths/heights anywhere in either file) — the
correct, responsive pattern. I could not find a structural cause for
overflow in either file as currently written. If you can reproduce the
clipping on a specific device/resolution, a screenshot would let me find
the actual element.

### 3. Dashboard Sales Trend chart
Added a real chart, not a placeholder: `dashboard_screen.dart` now also
watches `salesRepositoryProvider` (the same provider Sales List already
uses — no duplicate network call) and groups each sale's real `soldAt`
date into the last 7 calendar days client-side, since `GET /dashboard`
returns only today's totals but `GET /sales` has real per-sale dates.
Every bar is a genuine sum of real sales. Renders inside a rounded white
card matching the existing Dashboard card style, with day-of-week labels.
Handles all three states: loading (spinner), error (message, no crash),
and empty (a real 7-days-with-zero-sales case shows "No sales recorded
in the last 7 days yet" instead of a blank/misleading chart).

### 4. Reports bottom navigation
Investigated: in this codebase, `ReportsScreen` is pushed via
`Navigator.push` from the More menu as a standalone route — it had **no**
`bottomNavigationBar` at all, so whatever broken nav bar was observed on
your device wasn't in this file as delivered previously. Rather than
guess at a bug I can't reproduce, the fix reuses the exact same
`PillBottomNav` component Dashboard uses (zero duplicated nav logic) —
so Reports' nav bar is now guaranteed pixel-identical to Dashboard's:
same width/centering/height/icon size/`SafeArea` handling. Since Reports
is a pushed sub-page rather than one of the main shell's own tabs,
tapping any icon on it returns to the main shell (already underneath it
on the navigation stack) rather than faking a tab switch.

### 5. Category icons ("PH" bug)
Found and fixed the exact reported bug: `business_type_screen.dart`'s
tile was rendering `type.shortCode` ('PH', 'GR', 'RS'...) as literal text
in a `CircleAvatar`. Replaced with proper semantic Material icons
(pharmacy → `local_pharmacy_outlined`, grocery → `storefront_outlined`,
restaurant → `restaurant_outlined`, clinic → `local_hospital_outlined`,
clothing → `checkroom_outlined`, company → `business_outlined`, workshop
→ `build_outlined`) — reusing Flutter's built-in Material Icons, the
library already used everywhere else in the app; no new dependency.

Found and fixed the identical pattern in `settings_screen.dart`, where
tiles showed raw codes ('BZ', 'CUR', 'DK', 'LG', 'AI', 'OUT') the same
way — now proper icons there too.

### 6. Language switching (Arabic text staying English)
Root cause found: the `.arb` translation files
(`lib/core/localization/app_{en,ar,fr}.arb`) already had **complete,
matching translations for all 61 keys** in English, Arabic, and French —
verified byte-for-byte key parity across all three. What was missing was
the actual wiring: no `l10n.yaml`, no `generate: true` in `pubspec.yaml`,
no `AppLocalizations.delegate` registered in `main.dart`, and no screen
ever called `AppLocalizations.of(context)` — every screen had its
strings hardcoded in English regardless of locale. Changing the language
only ever flipped `TextDirection` via the `Locale`; the translated data
was sitting there unused.

Fixed:
- Added `l10n.yaml` (arb-dir, template, output config) and
  `generate: true` + `intl: ^0.19.0` to `pubspec.yaml`.
- Registered `AppLocalizations.delegate` in `main.dart`.
- Wired real translated strings into: **Onboarding, Login, Register,
  Business Type (including all 7 business-type labels/descriptions),
  Business Setup, the bottom nav labels, and the More menu** — every
  string on these screens now comes from `AppLocalizations.of(context)`,
  verified against the actual arb keys (61/61 referenced keys exist,
  cross-checked by script).
- Fixed a leftover from the earlier rebrand pass: `app_ar.arb`'s
  `appName` still said "سمارت بيز AI" (an Arabic transliteration my
  text-based "SmartBiz AI" find-and-replace didn't catch) — now "Modiri AI".

**Critical one-time step:** `lib/l10n/app_localizations.dart` is
generated code, not checked into this zip — Dart's l10n codegen only
runs via the Flutter SDK's build tooling, which isn't available in this
sandbox. **Run `flutter pub get` once** after unzipping (with
`generate: true` set, this triggers `flutter gen-l10n` automatically) —
the project will not compile until you do, the same as it wouldn't for
anyone setting up flutter's official l10n workflow for the first time.

**Remaining, explicitly not done:** Dashboard, Reports, Employees,
Products, Sales, Expenses, Invoices, Appointments, Settings' own body
text, and validation/error messages everywhere still have hardcoded
English strings — their `.arb` keys don't exist yet. I did not invent
rushed, unreviewed Arabic/French translations for dozens more strings
under time pressure; that's real content-authoring work I'd rather flag
than get subtly wrong. Also not yet swept: RTL visual correctness for
charts/forms/icons beyond what Flutter's `Directionality` already
mirrors automatically — worth a dedicated RTL pass once more screens are
translated.

### 7. Code quality
- Removed a dead `code` field from `main_shell.dart`'s
  `_MoreMenuItemData` (assigned, never read).
- No new dependencies beyond `intl` (required by any Flutter l10n setup)
  — no new chart library, no new icon package.

### What I could not do in this environment
Per the original request's testing section: I have no Flutter SDK, no
Android device, and no network access here, so I could not run
`flutter analyze`, `flutter pub get`, `flutter run`, or exercise the 45
listed test flows on a real device. Everything above was verified by:
reading the actual logic paths, a scripted brace/paren/bracket balance
check across all 58 Dart files (0 mismatches), a script cross-checking
every `l10n.xxx` call against the real arb keys (0 missing), and a
script confirming exact key parity across all 3 locale files. That is
real verification of correctness-by-construction, but it is **not** a
substitute for actually running the app — please do that before
shipping, and tell me what `flutter analyze` reports if anything is
non-obvious.

---

## Dashboard pixel-matching pass (against the provided reference screenshot)

Scoped strictly to matching the one concrete reference image provided —
no new charts/widgets/components were added; every change below either
fixes an existing element or reuses something already in the app.

### Fixed
- **Header/KPI clipping** — the old layout used `Transform.translate`
  across two separate slivers to fake the cards floating over the
  header; that's the standard way this kind of clipping bug happens in
  Flutter. Rebuilt as a single `Stack(clipBehavior: Clip.none)` inside
  one sliver — the cards can no longer be clipped by construction,
  regardless of the exact overlap amount.
- **Buttons** — rounded-rectangle buttons replaced with `StadiumBorder()`
  app-wide (theme-level, cascades everywhere) — full pill shape matching
  "+ New Sale" / "Scan Invoice" in the reference.
- **Bottom nav** — added the small active-state dot beneath the icon
  from the reference, replacing the earlier opacity+lift-only treatment.
- **KPI card subtitles** — added "Today · DZD" / "Today" / "Needs
  review"/"All good" to match the reference's card structure.
- **Low-stock alert** — now lists real low-stock product names (via the
  same `productsRepositoryProvider` Products screen already uses):
  "6 products are running low — Baguette Bread, Olive Oil…", and uses
  the amber/warning color from the reference.
- **Sales Trend** — added the Week/Month/Year pill toggle from the
  reference, reusing the existing `PillTabs` component (not a new one).
  All three ranges compute real totals from the already-loaded sales
  list at different groupings (daily/weekly/monthly buckets) — nothing
  fabricated.
- **Header text** — added a real `GET /companies/me` read to
  `companies_repository.dart` (alongside its existing write method) so
  "Amine · Grocery Store" can show the real company name + business
  type instead of nothing; degrades gracefully to a generic "Dashboard"
  label if that call fails.
- **Dashboard translations** — added 16 new keys (48 translations across
  en/ar/fr, parity-checked) and wired Dashboard fully into
  `AppLocalizations` — it's no longer only More that's translated.

### Deliberately not faked (flagged, not silently done)
- The reference shows "+12%" on the Profit card. `GET /dashboard`
  returns only today's numbers — there is no real comparison figure to
  compute that from. Showing "Today" instead of inventing a percentage.
- The reference's bottom nav shows 3 icons; this app has 4 real
  destinations (Dashboard/Sales/Inventory/**More**, where Settings,
  Employees, Reports, Invoices, Expenses, Appointments all live). Kept
  all 4 rather than unilaterally removing navigation to real screens —
  needs an explicit decision, not a guess, since it affects reachability.
- The nav icons in the reference look like distinct colored illustration
  assets, not monochrome outline icons. Kept Material icons (the
  library already used everywhere in this app) since matching custom
  icon art would need the actual asset files.

### Explicitly out of scope for this pass (need a reference to match against)
Reports, Review Items, and "all other screens" — I don't have a
Figma link or screenshots for these, so I can't do the same
measured, pixel-level pass on them without guessing. Please share
screenshots/exports the same way as the Dashboard one and I'll do the
identical treatment.

### Language/RTL — realistic status
Dashboard is now translated in addition to the nav/More/Auth/Onboarding
screens from the previous pass. Reports, Employees, Products, Sales,
Expenses, Invoices, Appointments, Settings body text, and all
validation/error messages **still have hardcoded English** — extending
real, reviewed translations to every remaining string across ~15 more
screens is a large content-authoring task I have not rushed through
carelessly. RTL correctness for charts/forms beyond Flutter's automatic
mirroring has not been separately audited yet.
