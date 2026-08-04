# W4 · account-status — implementation report

**Status: applied.** Branch `feat/redesign-24-migration`. One file touched, presentation only;
cubit / state / domain / data / l10n untouched, zero new endpoints, zero new strings, zero shared
files, no wiring request needed.

There is **no render for this screen** (the board drew 24; this is not one of them). The reference
was screen **20 · Settings** — the nearest redesigned neighbour in the user's journey — plus the
house precedents `dispute_status_screen.dart` (same D30 state machine + role-toned state note) and
`earnings_dashboard_screen.dart` (the bare padded title on a screen that must not carry a back
circle).

## File

- `lib/features/account_status/presentation/account_status_screen.dart` — re-skinned in place.
  No file created, none deleted, no private widget copied out of the kit.

## What changed

| Before | After |
|---|---|
| `Scaffold(appBar: OMDSAppBar(title:))` — centred M3 title bar | in-body padded title, `context.jeebText.h2` on `colorScheme.primary`, 24px gutter, mounted **above** the state switch so it renders identically in loading / failed / loaded |
| Body `Column(mainAxisAlignment: center)` — everything vertically centred | top-aligned scrolling band + `Expanded` empty white band + docked footer (R1: the emptiness is real, never centre) |
| `Icon(size: Sizes.sixXLarge, color: error)` — a 64px error glyph | dropped; the state now reads as a panel, not a wall glyph (the same `Icons.lock_outline_rounded` / `Icons.pause_circle_outline_rounded` survive as the note's 19px leading glyph) |
| banner = `theme.textTheme.titleMedium.copyWith(color: error, w600)`, centred | `JeebInfoNote.error(icon:, title:)` — the kit's stacked form: soft Wave-0 `errorContainer` fill, `onErrorContainer` ink, r16, pad 13/16, no shadow |
| reason = `theme.textTheme.bodyMedium`, centred | `context.jeebText.body` on `onSurfaceVariant`, start-aligned |
| two `OmdsPrimaryButton`s (primary + `variant: outlined`) inside the centred column, `Spacing.small` apart | `JeebCtaFooter.single(child: JeebCtaButton.primary, below: JeebCtaButton.outline)` — the board's docked footer, pad `0/24/32`, 10px stack |
| no scroll — a long server `reason` at 2× text scale overflowed | the content band is a `ListView`; the footer stays docked outside it |

Kit widgets consumed (no private copies): `JeebInfoNote.error` · `JeebCtaFooter.single` ·
`JeebCtaButton.primary` / `.outline`. Tokens: `context.jeebText.h2` / `.body`, `colorScheme.primary`
/ `.onSurfaceVariant`, `Spacing.*`, all insets `EdgeInsetsDirectional`.

## Refusals / deliberate divergences from the neighbour

1. **No `JeebTopBar`, therefore no back circle.** `/account-status` is a gate route —
   `app_router.backFallbacks` excludes it by name ("BACK must not bypass the lock / blocked-account
   gate"), and `JeebTopBar` has no leading-less mode (a fourth mode was refused kit-side). The
   sanctioned shape for that case is screen 19's bare padded title, which is what this screen now
   uses. Adding the circle would have been a navigation change, not a re-skin.
2. **No navy hero, no `JeebProfileHeader`.** `AccountStatusInfo` carries `{value, reason}` only —
   there is no name, phone or avatar to render. Building the neighbour's navy identity card would
   have meant inventing fields (constraint 3).
3. **No `JeebSectionLabel` band.** The screen has exactly one content block; a section header would
   have required a new user-visible string, i.e. an ARB + hand-written-parser edit or a wiring
   request, for pure decoration.
4. **No orange anywhere.** Nothing on a blocked-account screen is a "do-it-now / decaying" action;
   §3 rations the accent to exactly that. `Contact support` stays the navy primary pill.
5. **One error tone for both states.** Suspended → warning / locked → error would have been a
   semantic recolour nobody asked for; today both paint `colorScheme.error`, and the re-skin keeps
   that meaning (softened to the Wave-0 `errorContainer`, which is the stated desired outcome).
6. **`OmdsLoadingState` / `OmdsErrorState` left as-is** — the retry edge and its `Icons.error_outline`
   are test-pinned, and the redesigned `order_history` / `earnings` screens still use both. Left
   deliberately; see the self-critique.

The support route is intact and unchanged: `context.goNamed('support-ticket')`. The sign-out edge
still opens `LogoutDeleteConfirmSheet` in `both` mode.

## Frozen contracts

All five identifiers are byte-identical, in the same wrapper shape (`container: true`, plus
`button: true` on the two CTAs — the kit's own doc says the consumer owns the outer node for
buttons, so no `identifier:` was passed to `JeebCtaButton`):
`account_status_root` · `account_status_banner` · `account_status_reason` ·
`account_status_support_cta` · `account_status_signout_cta`.

## Verification

- `dart analyze lib/features/account_status` → **No issues found!**
- `flutter test test/features/account_status/account_status_screen_test.dart` → **7/7 pass**
  (unchanged file — no assertion was relaxed).
- `flutter test test/core/router/w0_routes_resolve_test.dart test/core/dev_seam/seam_landing_test.dart`
  → **41/41 pass**.
- Token gate patterns from `tool/check_design_tokens.sh` re-run against this file only: zero hits.
