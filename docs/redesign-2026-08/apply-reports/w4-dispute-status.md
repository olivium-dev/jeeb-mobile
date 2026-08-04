# w4 · dispute-status — implementation report

**Status:** applied. No render exists for this screen (it is outside the 24-screen board), so the
target was the *language* of its nearest neighbour, **12 · live-tracking** — the screen a client
reaches this one from.

**Files changed**
- `lib/features/dispute_status/presentation/dispute_status_screen.dart` (424 → 458 LOC, re-skinned)
- `lib/features/dispute_status/presentation/dispute_status_l10n.dart` (+2 feature-local strings)

No new files. No shared file touched (see `wiring/w4-dispute-status.md` for the one deferred ARB
request).

---

## What the neighbour does, and what this screen did instead

| 12 · live-tracking | dispute-status *before* |
|---|---|
| In-body `JeebTopBar`: Ø40 tonal back circle, navy title, no Material app bar | `OMDSAppBar` — a Material bar with a centred title and a tint |
| A 4-node `JeebStepper` band under the bar is the screen's primary visual | Nothing. An icon + coloured `titleMedium` row was the whole status |
| Content in r16 outlined cards / grey strip notes, 24px gutters, ~20px rhythm | Bare `Column`s of `Text` on white at 16px gutters, no cards at all |
| Two edges **docked** in a footer; the lower third stays deliberately white | `OmdsPrimaryButton` + `TextButton` scrolling as the last two list items |
| Every ink from a token (`jeebText`, roles) | `theme.textTheme.titleMedium/bodyMedium/labelLarge`, no ramp |

## What landed

**Header.** `OMDSAppBar` → `JeebTopBar` mounted as the first child of a `SafeArea > Column`, so it
renders in all three states (loading / failed / loaded) instead of only where a Scaffold hung one —
the `wallet_hub_screen.dart` pattern. `titleScale` stays `standard` (h2 20/w700): the `compact`
scale exists for 12's long two-line item summary, not for a two-word screen title. The bar's back
circle keeps the same edge as before (`_back` → order-chat / safe pop) and takes `leadingTooltip`
for its a11y label — **it deliberately carries no `identifier`**, because `dispute_status_back` names
one node and the widget test asserts `findsOneWidget` on it.

**The lifecycle stepper (new, from existing data).** `JeebStepper` with three nodes — Submitted ·
Under review · Resolved — `currentIndex = isResolved ? 2 : 1`, `pulseActive` while open. Wrapped in
`Semantics(identifier: 'dispute_status_stepper', container: true, explicitChildNodes: true)` per the
`OrderTrackingStepper` precedent, with new per-step ids `dispute_status_step_{submitted,review,
resolved}`. **No invented data:** the dispute exists, therefore it was submitted; `isResolved` is the
only other bit the contract carries. An `unknown` state rests on "under review" — exactly what the
state label already did before this change.

**State.** `dispute_status_state` is now `JeebInfoNote.success/.warning` (filled glyph + role
container fill) instead of a bare coloured row. These are the two kit tones that keep their role
colours on every surface — "the state is the message". The label strings are untouched, so
`find.text('Open — under review')` still passes.

**Outcome + evidence.** Both became `JeebSectionLabel` + card blocks. The outcome body is a
`JeebOutlinedCard` (`jeebText.body` on `onSurface`, the free-text note in `bodySmall` on
`onSurfaceVariant`). The evidence lines became `JeebOutlinedCard.grouped` of `JeebListRow`s
(`showChevron: false` — nothing here opens anything), filled R10 glyphs, and the comment line now
splits into `title: "Your note"` / `subtitle: <comment>` rather than a concatenated
`"Your note: …"` string. Same content, same order, same conditions.

**Empty evidence draws no card.** An outlined box with nothing in it implies evidence we do not
have; the heading renders alone, which is what the screen did before and what the widget test pins.

**Footer.** The two edges moved out of the scroll into `JeebCtaFooter.single` (navy primary
`Contact support`, `JeebCtaButton.text` `Back to chat` beneath). Order, destinations and copy are
unchanged.

**Tokens.** Every `theme.textTheme.*` is gone; the file now reads `context.jeebText.*`. `Spacing`
tokens only, `EdgeInsetsDirectional` only, 24px gutters, `Spacing.large` block rhythm,
`Spacing.small` between a section label and its card.

## Frozen contracts — preserved byte-identically

`dispute_status_root` · `dispute_status_state` · `dispute_status_outcome_note` ·
`dispute_status_evidence_summary` · `dispute_status_support` · `dispute_status_back` ·
`dispute_status_loading` · `dispute_status_error` · `dispute_status_retry_cta`.

Every one is still its **own screen-owned `Semantics(...)` wrapper with the same flags** — the kit's
`identifier:` parameter was used only for the new stepper ids, so no frozen node changed shape. The
`_back` edge logic, the `_resolveRepository` seam, `_formattedAmount` and the 4-state machine are
untouched.

## Refused / deliberately not done

- **No trailing action circle in the top bar.** 12 has one (→ chat); here the back CTA already *is*
  the chat edge, so a second one would be a new affordance, not a re-skin.
- **No bar subtitle.** 12's subtitle is tier + cash. The dispute carries only `orderRef` — a raw id
  is not user copy, and inventing a label for it needs an ARB key this lane does not own.
- **No submitted/resolved dates**, though `createdAt`/`resolvedAt` exist on the domain object: there
  is no formatter or copy for them here, and "Submitted Aug 1" would be new copy. Left alone rather
  than half-built.
- **No `JeebAccentFrameCard`, no orange fill anywhere.** The only orange on the screen is the
  stepper's active node — the rationed, do-it-now use the system prescribes.

## Gates

| Gate | Result |
|---|---|
| `dart analyze lib/features/dispute_status` | **No issues found** |
| `flutter test test/features/dispute_status` | **24 passed, 0 failed** (unchanged test file) |
| `flutter test test/core/theme/no_raw_semantic_colors_test.dart test/core/router/w3_w4_routes_resolve_test.dart` | **26 passed** |
| `bash tool/check_design_tokens.sh` | 3 violations repo-wide, **none in this feature** (location / wallet-activity / reviews — other lanes) |
| Layout probe (temporary, deleted): 390×844, `{en,ar} × {1.0,1.3,2.0}` × `{open,resolved}` | 12/12 rendered with **zero exceptions** — no overflow, RTL clean |
