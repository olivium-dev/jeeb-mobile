# `kyc-rejected` (JM-043) — apply report

**Status: applied.** Re-skin only. No new affordance, no reordered action, no copy change, no
navigation change. D52 held: `kyc_rejected_resubmit_cta` still does not exist and nothing that
could function as a resubmit was added.

**There is no render for this screen** — it is not one of the 24 on the board. It was brought onto
the design language by reference to its journey neighbour, **22 · Become a Jeeber**
(`docs/redesign-2026-08/screens/22-become-a-jeeber.png`), and to the already-migrated
`kyc_wizard_screen.dart`, which is the same feature area.

---

## Files changed

| File | What |
|---|---|
| `lib/features/kyc_rejected/presentation/kyc_rejected_screen.dart` | Sole screen file. `OMDSAppBar` → in-body `JeebTopBar`; raw `TextStyle`/`headlineSmall` → `context.jeebText`; hand-rolled `errorContainer` `Container` → `JeebInfoNote.error`; `OmdsPrimaryButton` + `TextButton` in a scrolling list → `JeebCtaFooter.single` with `JeebCtaButton.primary` / `.text`; centred column → start-aligned 24px-gutter band + real bottom whitespace. |
| `test/back_arrow_dead_at_root_test.dart` | ⚠️ **Shared file.** One-helper repair, see below and `wiring/w4-kyc-rejected.md`. |

No changes to `application/` (cubit + state untouched), no router, DI, theme, kit, l10n or pubspec
edits. No new strings.

## Kit widgets consumed (no private copies)

`JeebTopBar` · `JeebCtaFooter.single` · `JeebCtaButton.primary` · `JeebCtaButton.text` ·
`JeebInfoNote.error`.

## Tokens

`context.jeebText.h1` (headline) · `.body` (body copy) — the bar title and the two CTA labels are
inked by the kit. Colours: `colorScheme.primary` (headline), `.onSurfaceVariant` (body — **not**
periwinkle, §4.1's on-white ban), `.errorContainer` / `.onErrorContainer` (state mark; the note's
own tone comes from the kit). Spacing/size/radius all `Spacing.*` / `Sizes.*` /
`EdgeInsetsDirectional`. Zero raw hex, zero `fontSize:`, zero `EdgeInsets.only(<n>)`.
`bash tool/check_design_tokens.sh` reports **no violation under `lib/features/kyc_rejected`**.

## Semantics — every id byte-identical

`kyc_rejected_root` (same wrapper: `container: true, explicitChildNodes: true`) ·
`kyc_rejected_appeal_cta` · `kyc_rejected_back_cta` · `kyc_rejected_reason` — all four kept in
their existing explicit `Semantics(...)` wrappers rather than delegated to the kit's `identifier:`
param, so the node shape is unchanged too.

**One new id**, per the `<screen>_<element>` rule: **`kyc_rejected_back`** on the `JeebTopBar`
leading circle. It is not a new action — it is the same back arrow the `OMDSAppBar` drew, with the
identical `canPop() ? pop() : goNamed('customer-profile')` fallback (JEBV4-13 P1-6), which is what
`back_arrow_dead_at_root_test.dart` asserts. Exact-match finder semantics mean it cannot collide
with `kyc_rejected_back_cta`.

## D52 — refused nothing, added nothing

The design language wants a docked primary CTA; this screen already had one (`Appeal via support`),
so the footer is a re-home, not a new affordance. No "try again", no "resubmit", no "upload new
documents" was introduced, and no orange "do it now" accent was added to the appeal action —
appealing is not a decaying action, and dressing a final rejection in the accent that means *act
now* would misrepresent it.

## The one invention, stated plainly

The board has no rejection screen and therefore no screen-level state-mark component. The old
naked Ø64 `colorScheme.error` glyph reads as a Material error page, not as this product, so it
became a **Ø56 `errorContainer` disc with a 24px `onErrorContainer` glyph, start-aligned** — the
kit's own tonal-disc idiom (`JeebInfoNote.success`'s Ø30 check) scaled to a screen mark. It is
~12 lines of decoration in a private `_RejectionMark`, uses only tokens, is not a duplicate of any
kit widget, and is not tappable. It is nonetheless the only element on the screen with no board
precedent, and I would take a kit `JeebStateMark` over it if one ever lands.

## ⚠️ Shared-file edit (disclosed, applied, and why)

`test/back_arrow_dead_at_root_test.dart` taps three screens' back arrows through
`find.widgetWithIcon(IconButton, Icons.arrow_back)`. `JeebTopBar`'s leading circle is a
`MinTapTarget`, not an `IconButton`.

Timeline, observed during this lane:

1. First run of that suite, before I edited anything: **3/3 green.**
2. A **concurrent sibling lane** migrated `offer_kyc_gate_screen.dart` and
   `delivery_register_prompt_screen.dart` onto `JeebTopBar` at 16:10:58 / 16:11:19.
3. Next run: **1/3 green** — the two cases that are *not mine* now failed, with my screen still
   using the old app bar in that run.

So the finder was already broken for two screens independently of me. I repaired the **helper
once** (`find.byType(MinTapTarget)`) rather than only my own case, which restores all three to
green; assertions, destinations and the behaviour under test are untouched. Full patch, rationale
and the follow-up condition (what to do the moment one of those bars gains a trailing action) are
in `docs/redesign-2026-08/wiring/w4-kyc-rejected.md` §1.

## Verification

| Gate | Result |
|---|---|
| `dart analyze lib/features/kyc_rejected test/back_arrow_dead_at_root_test.dart` | **No issues found** |
| `flutter test test/decision_violations_test.dart` | **4/4 pass** (incl. the D52 group) |
| `flutter test test/back_arrow_dead_at_root_test.dart` | **3/3 pass** (was 1/3 pre-patch, not my doing) |
| `flutter test test/core/router/w2_routes_resolve_test.dart` | **7/7 pass** |
| `bash tool/check_design_tokens.sh` | 0 violations under `lib/features/kyc_rejected` (the script fails repo-wide on pre-existing violations in other features) |

Repo-wide `flutter analyze` and the full suite were **not** run — ~20 sibling lanes are editing
concurrently and the tree is not stable, as the incident above demonstrates.

## Known remaining gaps

See `selfCritique` in the lane's structured output; the substantive ones are the invented state
mark, the absence of any board-precedented `errorContainer` surface, the near-duplicate bar
title / headline copy (a copy problem this lane is not allowed to fix), and the fact that this
screen has no dedicated widget test of its own — its coverage is entirely the three shared suites
above.
