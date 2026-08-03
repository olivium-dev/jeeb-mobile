# w3 — `support-ticket` onto the Jeeb design system

**Target:** `lib/features/support/presentation/support_ticket_screen.dart` (single file — the feature
has no `presentation/widgets/` tree).
**Reference:** no board render exists for this screen. Applied the *language* of its neighbour,
screen 20 (`docs/redesign-2026-08/screens/20-settings.png` / `.html`), cross-checked against two
already-migrated siblings: `dispute_status_screen.dart` (the closest relative — it is the screen that
*links here*) and `wallet_hub_screen.dart` / `settings_screen.dart`.

## What screen 20 does that this screen did not

| 20-settings | support-ticket, before |
|---|---|
| In-body header: Ø40 `surfaceContainerHigh` back circle + 20/w700 navy title, 24px gutter | `OMDSAppBar` — a Material app bar with a 16px gutter and a different title ramp |
| Periwinkle uppercase `LANGUAGE` / `NOTIFICATIONS` band labels, ls +1.2 | `theme.textTheme.titleSmall` sentence-case headings |
| 24px side gutters | 16px (`Spacing.medium`) |
| Outlined cards / pill controls; selection is a **navy fill swap** (`English` pill) | a `ListTile` radio column — leading `radio_button_checked` glyphs, dense, high-density |
| Docked footer at the foot of a real empty band | two separately-padded blocks stacked under the scroll view |
| Filled glyphs throughout | `_outlined` glyph variants (`check_circle_outline`, `report_gmailerrorred_outlined`) |
| Stock M3 text ramp nowhere — everything is `jeebText` | `theme.textTheme.bodyMedium` / `titleLarge` / `titleSmall` |

## Changes made

1. **Header** — `Scaffold(appBar: OMDSAppBar)` → `Scaffold(body: SafeArea(Column([JeebTopBar.back, Expanded(…)])))`.
   The header now renders identically in all four phases (form / submitting / success / error), which
   the app-bar version already did but via Scaffold chrome; new id `support_back` on the leading
   circle (the `<screen>_back` kit contract). Leading tap behaviour is unchanged
   (`Navigator.maybeOf(context)?.maybePop()` ≡ `OMDSAppBar.showBackButton`).
2. **Gutters / rhythm** — one `_kBodyPadding` const, `24 / 16 / 24 / 24` directional, matching
   `dispute_status_screen.dart`'s constant of the same name and shape.
3. **Category picker** — `ListTile` + radio glyph column → a `Wrap` of `JeebSelectChip(role: filter)`.
   Same six options, same order, same single-select, same `support_category_<name>` wrappers.
   Selection is now the board's fill swap (navy + white w700). A `Wrap` (not `JeebChipRow.scrollable`)
   so no option can be scrolled out of the finder's reach.
4. **Band headers** — both `Text(titleSmall)` headings → `JeebSectionLabel` (uppercasing is internal
   and locale-gated, so AR passes through un-cased).
5. **Attachments** — `OmdsChip` → `JeebSelectChip(role: inlineAction, selected: true)`;
   `OmdsPrimaryButton(variant: outlined)` → `JeebCtaButton.outline(leadingIcon: Icons.attach_file)`.
6. **Footer** — the ad-hoc `TextButton.icon` + padded `OmdsPrimaryButton` pair → one
   `JeebCtaFooter.single`. **Order preserved**: the dispute link stays *above* the submit CTA, so the
   pair is passed as a stretch `Column` under `child:` rather than through `below:` (which renders
   under the primary and would have swapped the two). `TextButton` → `JeebCtaButton.text(expand: true)`
   keeps the full-width tap target the original comment called for.
7. **Tokens** — every remaining `theme.textTheme.*` → `context.jeebText.*` (`body` / `h1`), inked
   `colorScheme.onSurface` / `onSurfaceVariant` (never periwinkle as body text on white — §4.1 gate).
   Outlined glyphs → filled (R10): `check_circle`, `report`.
8. **Untouched on purpose** — both `OmdsTextField`s (the kit ships no input primitive; the migrated
   `profile_edit_screen.dart` sets the precedent), `OmdsLoadingState`, `OmdsErrorState`, every
   `Semantics(identifier:)` byte, all copy, all routes, `SupportCubit` and the DI/`extra` resolution.

## Gates

| Gate | Result |
|---|---|
| `dart analyze lib/features/support test/features/support` | **No issues found** |
| `flutter test test/features/support` | **13 passed, 0 failed** |
| `flutter test test/core/router/w3_w4_routes_resolve_test.dart` | 9 passed |
| `flutter test test/features/account_status/account_status_screen_test.dart` | 7 passed |
| `flutter test test/decision_violations_test.dart` | 4 passed |
| `grep 'fontSize:\|Color(0x'` in the target | 0 hits |

No pubspec, l10n, theme, kit, router or DI file was touched — no wiring request is owed.

## Left open (not this lane's to close)

- **Dedicated `supportCategory*` / `supportBodyLabel` / `supportAttachLabel` ARB keys.** The screen
  still reuses the closest existing strings, exactly as before (`customerProfileSectionSupport`,
  `navEarnings`, `kycRejectedAppealCta`, `escalateCommentLabel`, `ordersTitle`, `escalatePhotoLabel`).
  Restyling made this *more* visible — the category band label renders `CONTACT SUPPORT`, which
  repeats the top-bar title and the `account` chip's own label. Closing it needs a coordinated
  `app_en.arb` + `app_ar.arb` + `app_localizations.dart` edit; flagged, not faked.
- The screen has no honest source for a navy hero or any expiring/do-it-now moment, so it carries
  **no navy surface and no orange at all**. That is the correct reading of the rationing rule for a
  static form, but it does make it the quietest screen in its neighbourhood.
