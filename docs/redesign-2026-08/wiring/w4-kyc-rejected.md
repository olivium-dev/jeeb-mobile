# Wiring request — `kyc-rejected` (undesigned screen, applied against neighbour 22)

Lane: `lib/features/kyc_rejected/**`. One shared-file change, **already applied** (see the ⚠️
below) because leaving it unapplied would have left a shared test RED for three screens, not one.

---

## 1. `test/back_arrow_dead_at_root_test.dart` — back-arrow finder (APPLIED)

**Why.** That suite taps the AppBar back arrow on three screens
(`offer-kyc-gate`, `delivery-register-prompt`, `kyc-rejected`) via

```dart
Finder _appBarBackButton() => find.widgetWithIcon(IconButton, Icons.arrow_back);
```

All three screens have now been migrated off `OMDSAppBar` onto the kit `JeebTopBar`, whose leading
circle is `Semantics > MinTapTarget > DecoratedBox > Icon` — **there is no `IconButton`**, so the
finder resolves to zero widgets and every case in the file throws.

`offer_kyc_gate_screen.dart` and `delivery_register_prompt_screen.dart` were migrated by a
**concurrent sibling lane at 16:10–16:11 today** (observed mid-run: the file was green on my first
execution and red on my second, with my screen untouched between them). That lane appears not to
have repaired the finder.

**Patch applied** (import + helper; no assertion, no navigation expectation touched):

```dart
import 'package:jeeb_mobile/core/accessibility/accessibility.dart';
```

```dart
/// The screen's back affordance.
///
/// redesign-2026-08: all three screens under test replaced their Material
/// `OMDSAppBar` with the in-body kit `JeebTopBar`, whose leading circle is a
/// `MinTapTarget` + `Icon`, not an `IconButton`. None of the three bars carries
/// a trailing action or an identity avatar, so the leading circle is the only
/// `MinTapTarget` on each. The guarded-fallback behaviour under test is
/// unchanged — only the handle is.
Finder _appBarBackButton() => find.byType(MinTapTarget);
```

**Result:** `flutter test test/back_arrow_dead_at_root_test.dart` → **3/3 pass** (it was 1/3 before
the patch, on a tree I had not yet touched).

⚠️ **Integrator:** if the `offer_kyc_gate` lane submits its own repair of this helper, take one of
them, not both. `find.byType(MinTapTarget)` becomes ambiguous the moment any of those three bars
gains a trailing action or an identity avatar — at that point switch to
`find.bySemanticsIdentifier('<screen>_back')` (ids exist on all three:
`offer_kyc_gate_back`, `delivery_register_prompt_top_back`, `kyc_rejected_back`) and add a
`tester.ensureSemantics()` handle to the suite.

---

## 2. No l10n request

Zero new user-visible strings. The screen reuses `kycRejectedTitle` / `kycRejectedHeadline` /
`kycRejectedBody` / `kycRejectedAppealCta` / `kycRejectedBackCta` / `kycRejectionReason*` verbatim.
`@kycRejectedTitle`'s ARB description still reads *"JM-043 kyc-rejected OMDSAppBar title"* — now
stale wording (it is a `JeebTopBar` title). **Not changed**: `lib/l10n/*` is not mine, and the
description is not user-visible. Fix it in the l10n sweep if you want it accurate.

## 3. No router / DI / theme / kit / pubspec changes

None needed. Both edges (`support-ticket`, `customer-profile`) already exist and are unchanged.
