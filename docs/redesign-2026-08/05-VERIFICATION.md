# 05 — Verification gate, redesign-2026-08

Run on `feat/redesign-24-migration`, 2026-08-03, after the 24 screen agents + the wiring
integrator. Local Flutter 3.44.2. All numbers below are measured, not estimated.

---

## Verdict

**At baseline on analyze, better than baseline on tests.** 22 regressions were found and all 22
are fixed. The 2 tests still red are 2 of the 4 the baseline names as pre-existing; the other 2
pre-existing failures were incidentally fixed by the migration.

| Gate | Baseline (`_BASELINE.md`) | First measurement | After this pass |
|---|---|---|---|
| `flutter analyze` | 5 issues · 0 errors · 0 warnings | 9 issues · 0 errors · **1 warning** | **8 issues · 0 errors · 0 warnings** |
| `flutter test` | +3863 · ~61 skipped · **−4** | +4579 · ~61 · **−24** | **+4601 · ~61 · −2** |
| `test/core/widgets/jeeb/` (frozen kit) | 476 | 476 | **476, all passed** |
| `decision_violations_test` + `qa_keys_batch_test` | pass | pass | **pass (8)** |

The frozen kit was never touched by a screen agent — 476/476 both before and after.

---

## Analyze delta

Baseline was 5 `containsSemantics` deprecation **infos** in test files, invisible to CI (CI pins
Flutter 3.38.9, which predates the deprecation).

**Regression found and fixed (1):**

| File | Issue | Fix |
|---|---|---|
| `test/features/chat/chat_quick_reply_bar_test.dart:13` | `warning • unused_import` on `chat_gateway.dart` | Import removed. `ConversationPhase` and `FakeChatGateway` both reach the file through other imports. |

**Not fixed, deliberately (3 infos):** `chat_screen_test.dart:126`, `:133` and the new
`test/features/chat/order_chat_strip_redesign_test.dart:85` each add a `containsSemantics` call,
taking the class from 5 to 8. These are **correct as written**: the suggested replacement
`isSemantics` does not exist in CI's Flutter 3.38.9, so migrating them would turn 3 local infos
into 3 CI compile errors. Same benign class as the 5 baseline occurrences, same reason to leave
them.

Final: `8 issues found`, **0 errors, 0 warnings**.

---

## Test delta — the 22 regressions, and what each one actually was

### 1. `test/features/order_history/order_history_card_test.dart` — 5 failures · test defect

`A SemanticsHandle was active at the end of the test.` The new file registered
`addTearDown(handle.dispose)`, but `flutter_test` runs `_endOfTestVerifications` at the end of the
test **body**, before any tearDown fires — so the handle is always still live when the check runs.
Every other `ensureSemantics()` site in this repo (18 files) disposes inline; this file was the
only one using `addTearDown`.

**Fixed in the test:** three sites switched to an explicit `handle.dispose()` at the end of the
body, with a comment naming the ordering. No assertion touched. → 20/20 green.

### 2. `test/order_history_screen_test.dart` — 5 failures · real layout bug

`RenderFlex overflowed by 41px` (ar, 1.0×), `by 173px` (en, 2.0×), and the same in both date-filter
tests. Creator chain: `Row ← Padding ← DecoratedBox ← JeebTierChip ← Flexible ← Row ← _MetaRow`.

Root cause in `lib/features/order_history/presentation/order_history_card.dart`: `_MetaRow` wrapped
the kit's `JeebTierChip` in a `Flexible`. The kit chip's inner row is `MainAxisSize.min` and its
label does not ellipsize, so **any** max width below its intrinsic width overflows it. Arabic
labels and 2× text both cross that line.

**Fixed in the implementation (kit untouched), two parts:**
- The tier chip is no longer `Flexible` — it lays out at its intrinsic width and the two meta
  `Text`s (which *do* have `maxLines: 1` + `TextOverflow.ellipsis`) absorb all shrinkage.
- Above **1.5× text** the tier chip is dropped entirely, via a new
  `OrderHistoryCard.largeTextScaleThreshold = 1.5`. This reuses the exact threshold the screen
  header already uses (`_kLargeFilterTextScaleThreshold`) to stop sharing a line between its two
  bands. Past 1.5× the chip alone is wider than the whole meta group, while the date, status and
  action pill are all load-bearing. The card's own comment already records that tier stays
  available on `/orders/:id`.

→ `order_history_screen_test.dart` + `test/features/order_history/` = 89/89 green.

### 3. `test/client_home_screen_test.dart` — 4 failures · 3 real layout bug + 1 stale assertion

**3 of 4** — `RenderFlex overflowed by 35px` from
`Row ← Padding ← JeebChipRow ← _ClientHomeTabBar`. The Requests tab bar moved to `JeebChipRow` at
gutter 24 (per `per-screen-revised/04-client-home.md` Task 6) and gained count badges; with both,
"Pending Requests" + "Replies" no longer fit a 390pt gutter-to-gutter line even in EN.

**Fixed in the implementation:** `JeebChipRow` → `JeebChipRow.scrollable`, the kit form intended
for exactly this (and already used by screen 24's tab pills at
`order_history_screen.dart:110`). The kit doc calls out that this form is a **non-lazy** `Row`, so
both chips remain resolvable by `find.bySemanticsIdentifier` even when scrolled off — the
`orders_filter_pendingRequests` / `orders_filter_replies` / `orders_home_replies_tab` id contracts
are unchanged. No `Semantics(identifier:)` value was altered.

**1 of 4** — `create-request hero uses primary card fill + accent mic` asserted the mic disc colour
by walking `Container` descendants of `JeebMicHero`. The kit paints that disc with a bare
`DecoratedBox`, so the search returned `[]`.

**Fixed in the test:** the walk now targets `DecoratedBox`. Identical assertion — same colour, same
`reason` string ("the mic disc must be jeebRoles.accent, not a disabled gray") — pointed at the
current paint node. Nothing weakened.

→ 18/18 green.

### 4. `test/features/rating/mutual_rating_redesign_test.dart` — 3 failures · test defect

`Found 0 widgets with text "Great"`. Probed directly: the cubit reached `stars=4` but the
`_StarVerdict` element in the tree still held `stars=0` and returned its `SizedBox.shrink()` branch;
a *second* `setStars` then rendered the *first* one's word. The screen and the l10n
(`mutualRatingStarLabel1..5`, both locales) are correct.

Cause: the cubit is driven from outside the widget, and bloc delivers on a broadcast stream, so the
`BlocConsumer` listener fires on a microtask **after** the frame the single `await tester.pump()`
builds. One frame of lag in a test; invisible in production, where the emit is followed by a normal
vsync.

**Fixed in the test:** a second `await tester.pump()` after each `setStars`, with a comment naming
the mechanism. → `test/features/rating/` 18/18 green.

### 5. `test/core/router/w1_routes_resolve_test.dart` — 1 failure · test-harness gap

`_TypeError: Null check operator used on a null value` at
`delivery_receipt_screen.dart:375` — `Theme.of(context).extension<JeebSemanticColors>()!`. The
harness mounted `MaterialApp.router` with **no theme**, so the default `ThemeData` carries no Jeeb
theme extension. The screen is using the sanctioned Wave-0 accessor; the harness was simply less
production-like than `app.dart`.

**Fixed in the test harness:** `theme: AppTheme.light()`, i.e. exactly what `app.dart:628`
installs. → 8/8 green.

### 6. `test/features/active_delivery_jeeber/active_delivery_jeeber_golden_test.dart` — 3 failures · legitimate redesign

Pixel diffs of 18.00% / 16.63% / 24.26% against a 5% tolerance, on all three goldens. The screen
was deliberately rebuilt (stepper pills replacing the icon rail, chip back-button, address card,
paired footer). Goldens regenerated with `--update-goldens` and **all three visually inspected**
before acceptance:

- `english_phone` — stepper pills, navy CTA, outlined address card, Maps/Chat footer pair. Correct.
- `arabic_rtl_phone` — fully mirrored: stepper runs right-to-left, pin and chevron swap sides,
  footer order reverses. No LTR leakage.
- `english_200_percent_text` — degrades by ellipsis and wrap, footer stacks, nothing clipped.

(The red corner ribbon is present in the *old* goldens too — a pre-existing harness artifact, not
introduced here.)

### 7. `test/mb1/mb1_doc_residual_receipts_test.dart` — 1 failure · environmental

`these .dart files exist on disk but git does not track them, so V-1 CANNOT see a residual in them.
Stage them, or the receipts are measuring a different tree than the gate.` The gate's lens is
`git ls-files`; 123 new `.dart` files from Waves 0/1 and the 24 screens were untracked, so the
receipts were measuring a different tree than the audit.

**Fixed as the test instructs**, minimally: `git add -N` (intent-to-add) on every untracked `.dart`
file under `lib/` and `test/`. That records the *paths* in the index — enough for `git ls-files`
and `git grep` — without staging content, and it is reversible with `git reset`. **No commit, no
branch, no push.** → `test/mb1/` 33/33 green.

---

## Still failing — 2, both pre-existing, neither this migration's

| Test | Reason it is not ours |
|---|---|
| `test/core/diagnostics/gesture_log_test.dart` — *records the OUTER exposed id, not inner* | Named in `_BASELINE.md`. Local-SDK skew; passes in CI. |
| `test/jeeber_feed_card_test.dart` — *accepted-action pill is end-aligned* | Named in `_BASELINE.md`. Red on `main@03c6c74` in CI too. |

**Two of the four baseline failures now pass** and were not touched by me:
`test/client_offers_screen_test.dart` (sort-chip hit targets — screen 11's rebuild fixed it) and
`test/mutual_rating_tag_chips_l10n_test.dart` (ar canonical wire value — screen 15's rebuild fixed
it). Worth reporting upstream, since both are red on `main` in CI.

---

## Everything changed by this gate

**Implementation (2 files):**
- `lib/features/order_history/presentation/order_history_card.dart` — tier chip un-flexed; new
  `largeTextScaleThreshold` const; tier dropped above 1.5× text.
- `lib/features/home_client/presentation/client_home_screen.dart` — `JeebChipRow` →
  `JeebChipRow.scrollable` on the Requests tab bar.

**Tests (5 files):**
- `test/features/order_history/order_history_card_test.dart` — inline `handle.dispose()` ×3.
- `test/client_home_screen_test.dart` — mic-disc assertion walks `DecoratedBox`.
- `test/features/rating/mutual_rating_redesign_test.dart` — second `pump()` ×3.
- `test/core/router/w1_routes_resolve_test.dart` — harness installs `AppTheme.light()`.
- `test/features/chat/chat_quick_reply_bar_test.dart` — unused import removed.

**Goldens (3 files):** the `active_delivery_jeeber` set, regenerated and eyeballed.

**Index:** `git add -N` on 123 untracked `.dart` files. Nothing committed.

No test was deleted, no assertion weakened, no `Semantics(identifier:)` value changed, no pubspec
dependency added, and no file under `lib/core/widgets/jeeb/` edited.

---

## Two things an owner should look at

1. **`JeebChipRow` (fixed form) has no overflow protection.** Two consumers hit it independently
   (screens 04 and 24) with different symptoms. Every consumer of the fixed form is one long
   translation away from a `RenderFlex` overflow. Either the kit's fixed form should clip/scroll on
   overflow, or `03-WAVE1-KIT.md` should say plainly that the fixed form is only for content whose
   width you control.
2. **`JeebTierChip` cannot be constrained.** Its inner row is min-sized and its label has no
   ellipsis, so it overflows under any `Flexible`/`Expanded` parent. The consumer-side workaround is
   in place; a `maxLines`/`overflow` on the kit label would remove the trap.

Neither was changed here — the kit is frozen.
