# w3 — `no-offer-timeout` (waiting / no-coverage) onto the Jeeb design system

Target: `lib/features/no_offer_timeout/presentation/no_offer_timeout_screen.dart`
Route: `/requests/:id/waiting` (`waiting-no-coverage`) — the state immediately BEFORE 11 offer-review.
**No board render exists for this screen** (it is one of the 46 the board never drew), so the
reference is the neighbour it hands off to: `screens/11-offers.png` + the shipped
`ClientOffersScreen` / `OfferWindowTimer`.

## What the neighbour does, and what this screen did differently

| 11 offer-review (redesigned) | waiting (before this change) |
|---|---|
| In-body `JeebTopBar.back` — title + back circle share the 24 gutter, render in every state | Material `OMDSAppBar` |
| Countdown = grey strip, Ø8 orange dot, one navy w700 line, meter at the end | Countdown = a centred `bodyLarge` sentence in `onSurfaceVariant` |
| Outlined r16 cards, 1.5px stroke, no shadow | One grey `surfaceContainerHighest` slab (`Container` + `OmdsBorderRadius.uiLarge`) |
| Type from `context.jeebText` (h2 / cardTitle / bodySmall) | `theme.textTheme.headlineSmall / titleMedium / bodyLarge / labelSmall` |
| Actions docked at the foot of the viewport, list top-aligned over white | Three full-width buttons inline at the end of the scroll body |
| "Cancel request" = warm dark text action (`onSurfaceVariant`) | Cancel = `colorScheme.error` red text button |
| 24px gutters | `EdgeInsets.all(Spacing.large)` = 20 |

## What changed (re-skin only — no flow, copy or logic change)

- `OMDSAppBar` → **`JeebTopBar.back`** in-body, `identifier: 'waiting_back'` (new id, `<screen>_back`
  convention). `onLeadingPressed` resolves `canPop() ? pop() : go('/')` — byte-equal to the route's
  own registered `backFallbacks['waiting-no-coverage'] = '/'`, so the arrow is never dead on the
  stack root the screen usually is.
- Countdown → **`JeebInfoNote`** strip carrying `identifier: 'waiting_countdown'`, with the Ø8
  `jeebRoles.accent` dot and tabular figures — the same shape `OfferWindowTimer` gives 11's window.
  `accent` tone while a countdown exists, `muted` + hourglass for the honest
  "no countdown applies" variant (that state is not a do-it-now moment and must not spend the
  rationed orange).
- Request echo (G1) → **`JeebOutlinedCard`** + **`JeebSectionLabel`** + `jeebText.cardTitle`.
- Three CTAs → **`JeebCtaButton`** (`primary` review-offers / `outline` re-target / `text` cancel)
  docked in **`JeebCtaFooter.single`**. Same three affordances, same order, same edges.
- Terminal home CTA → `JeebCtaButton` (Key + `Semantics` wrapper unchanged).
- Every `theme.textTheme.*` → `context.jeebText.*`; muted ink → `JeebSemanticColors.mutedText`
  (periwinkle), headlines → `jeebText.h1` on `colorScheme.primary`.
- Gutters 20 → 24; 16 above the first block, 24 of air before the docked footer.

**Unmoved, deliberately:** all ten existing `Semantics(identifier:)` wrappers byte-identical
(`waiting_notified_count` `waiting_countdown` `waiting_no_coverage_state` `waiting_review_offers_cta`
`waiting_retarget_cta` `waiting_cancel_cta` `waiting_terminal_state` `waiting_terminal_home_cta`
`waiting_error_state` `waiting_request_description`); both `JeebLottieMark`s (08-MOTION-SPEC §2.3 /
§2.7 assign them here); the cubit, the push/resume wiring and every navigation edge; all copy — no
ARB key was added, so **no l10n wiring request was needed**.

## Refusals / flagged, not faked

- **No meter on the countdown strip.** 11's strip carries a `JeebMeter`; `WaitingState` exposes
  `remaining` only — there is no window length on the wire and the waiting cubit keeps no
  observed-maximum the way `ClientOffersState.windowTotal` does. A meter here would render either a
  permanently empty track or a fraction that jumps back to full on every refresh. Omitted, not
  invented. (Fixing it properly is a cubit change, out of a re-skin's scope.)
- **No top-bar subtitle.** 11 puts the request title there; here the title is the `waiting_request_description`
  echo card (sprint-009 G1, test-pinned) and duplicating it would say the same thing twice.
- Cancel is no longer red. This is intentional alignment: 11 renders the identical action as a warm
  dark text CTA, and `JeebCtaButton.text` owns that ink.

## One test edit

`test/features/no_offer_timeout/waiting_screen_test.dart` — the G1 assertion `find.text('Your request')`
now derives its expectation via `JeebSectionLabel.resolveCase('Your request', const Locale('en'))`,
because the kit's section label owns the locale-gated uppercase transform (03-WAVE1-KIT §2.4 names
`resolveCase` as the way tests should derive `find.text()`). No behavioural assertion changed.

## Gates

| Gate | Result |
|---|---|
| `dart analyze lib/features/no_offer_timeout test/features/no_offer_timeout` | **No issues found** |
| `flutter test test/features/no_offer_timeout --no-pub` | **56 passed, 0 failed** |
| `flutter test test/core/theme/no_raw_semantic_colors_test.dart test/core/router/w1_routes_resolve_test.dart` | **25 passed** |
| Raw `Color(0x…)` / raw `fontSize` in the screen | 0 |
