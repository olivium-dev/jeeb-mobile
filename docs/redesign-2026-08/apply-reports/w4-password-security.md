# w4 — password-security → Jeeb design system

**File:** `lib/features/password_security/presentation/password_security_screen.dart` (the only file
in the lane; `application/` and `domain/` untouched).
**Reference:** no render exists for this screen. Nearest neighbour = **screen 20 (settings)**;
nearest already-migrated *sibling* = `settings/presentation/screens/profile_edit_screen.dart`,
which is the same shape (a short form reached from the profile) and was followed for house
conventions.

---

## What the neighbour does, and what this screen did instead

| 20-settings render | password-security, before |
| --- | --- |
| In-body header: Ø40 `surfaceContainerHigh` back circle + left-aligned navy 20/w700 title | Material `OMDSAppBar` — centred title, app-bar ink, a bare `BackButton` |
| 24px side gutters on every band | 16px gutters, 20px top |
| Kit CTAs (navy pill / outlined pill), full-pill radii | `OmdsPrimaryButton` (`primary` + `outlined` variants) |
| Errors/notices are soft panels; the hard `#B00020` slab is what Wave 0 removed | two inline `theme.textTheme.bodyMedium` + `colorScheme.error` red text lines |
| Type comes from the ramp | body copy from the stock M3 `TextTheme` |

## What changed

1. **Header → `JeebTopBar.back`**, mounted as the first child of a `Column` inside `SafeArea`
   (`Scaffold(appBar: null)`), exactly as screen 20 and profile-edit do. `password_back` moved onto
   the kit's leading circle — the `<screen>_back` contract the kit owns. The guarded
   `canPop ? pop : goNamed('customer-profile')` edge is byte-identical.
2. **Gutters → 24px** (`Spacing.xLarge`), top `Spacing.medium`, bottom `Spacing.xLarge`.
3. **Lead-in sentence → `context.jeebText.body`** on `colorScheme.onSurfaceVariant`
   (`#5C4038`). Deliberately *not* `mutedInk`/periwinkle — that ink is banned as body text on
   white and a contrast test asserts it.
4. **Both validation nodes → `JeebInfoNote.error`** (`icon: Icons.error`, filled per R10). Wave 0's
   soft error family is what this panel was designed for; the copy (`setpwValidationError`) is
   unchanged and the two guards remain mutually exclusive (the policy returns one verdict).
5. **Submit → `JeebCtaButton.primary`**, **social entry → `JeebCtaButton`** with
   `outline`/`primary` chosen by `hasPassword` — the same variant split the OMDS buttons had.
6. **Rhythm:** 16 between fields, 12 binding the error note to the field group, 24 before the
   Save pill, 12 between the two stacked CTAs.

## What deliberately did NOT change

- **Order and flow.** Save stays above "Set a password"; nothing was docked into a
  `JeebCtaFooter`, because moving the primary CTA into a footer would have put the social entry
  *above* it — a reorder, which the brief forbids. The screen is short enough that the in-flow
  stack reads fine.
- **Every `Semantics(identifier:)`** — all eleven ids are byte-identical, including the two
  wrappers that carry `liveRegion: true` without `container:`/`explicitChildNodes:`.
- **`OmdsTextField`** stays. The kit ships no input primitive, and `profile_edit_screen.dart`
  documents the same decision ("swapping it would be churn, not migration").
- **No new strings.** This repo has no gen-l10n; every visible string is an existing ARB key.
- **No new affordances.** The current-password field still has no eye toggle (there is no id for
  one), and no section labels were invented.

## Gates

| Gate | Result |
| --- | --- |
| `dart analyze lib/features/password_security` | **No issues found** |
| `flutter test test/features/password_security` | **15/15 pass** |
| `flutter test test/core/router/w3_w4_routes_resolve_test.dart` | **9/9 pass** |
| `tool/check_design_tokens.sh` | no hits in this lane |
| `grep "Color(0x\|fontSize:"` in the file | 0 |

## Residual gaps (honest)

- **The fields are still OMDS-shaped:** white fill, **1px `#CBD0E0` cool-grey** border, **r12** —
  against the system's 1.5px warm-brown `#916F66` at r16. Fixable only in OMDS (out of scope, CI
  pulls it fresh) or by per-call-site `borderRadius:`/`fillColor:` overrides, which would fork this
  screen away from its own sibling. Left alone deliberately.
- **No section labels.** Screen 20's defining rhythm is `SECTION LABEL → card`; this screen has no
  ARB key that fits one, and inventing copy is out of lane. `profile_edit_screen.dart` has the same
  shape (only its read-only band carries a label), so the two siblings are at least consistent.
- **No navy surface.** The only navy is the Save pill; the neighbour anchors with a navy identity
  card. There is no data on this screen to build a hero from — rendering one would be decoration.
- **Two stacked pills at different heights** (56 primary / 50 outline). That is the kit's own
  measured pair (14 does 58/54); left at the defaults rather than overridden.
