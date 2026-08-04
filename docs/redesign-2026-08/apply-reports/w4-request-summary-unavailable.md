# w4 — `request-summary-unavailable` onto the Jeeb design system

**Lane:** `request-summary-unavailable`
**File:** `lib/features/request_summary/presentation/request_summary_unavailable_screen.dart` (the only file changed)
**Reference render:** none exists for this screen. Language taken from its journey neighbour
`docs/redesign-2026-08/screens/10-request-summary.png` and from the already-redesigned sibling in the
same directory, `request_summary_screen.dart`.

---

## What the neighbour does, and what this screen did

Screen 10 is: Ø40 tonal back circle + navy `h2` title in a **body row** at the 24px gutter → one
block starting immediately below at the same gutter → ~45% **real white emptiness** (R1) → a docked
navy pill. Orange appears only as three small `Edit`/`Change` links. Nothing is vertically centred.

The unavailable screen was a Material `OMDSAppBar` over a `Center(OmdsErrorState(...))`:

- a **Material app bar** — elevation, `headlineSmall` title — where all 17 spine screens (and its own
  sibling on the same route) use the in-body `JeebTopBar`;
- a **64px `colorScheme.error` glyph** — the single largest red/warm mass on a screen, on a state
  that is *empty*, not *failed*, in a system where the accent is rationed;
- **vertically centred** content, which R1 forbids outright;
- Material `textTheme.bodyMedium` ink rather than the Jeeb ramp;
- no gutter of its own (`OmdsErrorState`'s internal `Spacing.large` = 16, not the board's 24).

## What changed

| Before | After |
|---|---|
| `OMDSAppBar(title:, showBackButton: true)` | `JeebTopBar.back(title:, identifier: 'request_summary_unavailable_back')` — the same guarded `maybePop` default, so no behaviour change |
| `Center(child: OmdsErrorState(icon: inbox_outlined, message:))` | `JeebInfoNote.muted(icon: inbox_outlined, text:)`, top-aligned in the 24px gutter, 16px below the bar |
| implicit `Scaffold` body | `SafeArea` → `Semantics(identifier: 'request_summary_unavailable_root')` → `Column` → bar / `Expanded(SingleChildScrollView)` — the sibling's exact shell |
| centred content, no residual emptiness | residual space below the note stays plain white (R1) |

Copy, glyph, route, back behaviour and the `Key('request-summary-unavailable-state')` are unchanged.
No l10n keys added or edited. No shared file touched — **no wiring request needed**.

### Identifiers
- `Key('request-summary-unavailable-state')` — **preserved byte-identically**, moved onto the note.
- New (this screen had none): `request_summary_unavailable_root`,
  `request_summary_unavailable_back`, `request_summary_unavailable_note`.
- Deliberately **not** `request_summary_back`: that id belongs to `RequestSummaryScreen`. The two
  never coexist but do share the `/request-summary` route, so distinct ids keep the contract
  unambiguous.

## What was deliberately NOT done

- **No CTA added.** The body copy says "Start a new request to continue", and the neighbour's
  structure is `content → flex → dock`, so a docked "Start a new request" pill is the obvious
  completion. It is refused here: it is a **new affordance** (a product change, not a re-skin) and it
  needs a new l10n key, which means a shared-file edit. Flagged for the owner, not built.
- **No `canPop ? pop : go('/')` back fallback**, even though the sibling on the same route has one.
  That is a navigation change. The bar keeps the guarded `maybePop` the `OMDSAppBar` already used.
- **No new illustration.** `_ds/readme.md` wants empty states built on the mic/waveform or the 3D
  delivery render; neither asset is wired for this feature, so the existing `inbox_outlined` glyph
  stayed rather than an invented one.

## Verification

- `dart analyze lib/features/request_summary/` → **No issues found!**
- `flutter test test/core/router/request_summary_route_test.dart test/features/request_summary/` →
  **76 passed** (includes the three cold-deep-link fallback cases that pin this screen).
- `flutter test test/features/request_type/request_type_continue_navigation_test.dart` → 1 passed.
- `flutter test test/devtool/catalog_network_guard_test.dart` → 2 passed (the screen has a catalog
  entry).
- Full suite and repo-wide analyze not run — ~20 lanes editing concurrently.

## Remaining inconsistencies vs the neighbour (honest)

1. **No dock.** Screen 10 ends in a navy pill + caption; this screen ends in white. Correct for a
   screen with no action, but structurally lighter than every neighbour. See "not done" above.
2. **The body sits at 12px.** `JeebInfoNote`'s strip form renders `bodySmall`, so the only copy on
   the screen is at note scale — quieter than the neighbour's card body. Raising it would mean the
   `label` escape hatch (which the kit reserves for *ink or spans*, not scale) or forking the kit;
   neither is worth it for a fallback surface.
3. **Grey note vs warm outlined card.** The neighbour's single block is a `JeebOutlinedCard` with the
   warm-brown stroke. The mapped widget for this content is the note (`notes/banners →
   JeebInfoNote`), so the block reads as secondary where the neighbour's reads as primary. An
   `JeebOutlinedCard` placed in the ticket's exact slot would echo the render more literally — a
   defensible alternative, not obviously better.
4. **Back is still a no-op on a true cold deep-link** (empty stack → `maybePop` does nothing).
   Pre-existing, unchanged, and exactly the case this screen exists for. Worth an owner decision
   alongside the CTA question.
