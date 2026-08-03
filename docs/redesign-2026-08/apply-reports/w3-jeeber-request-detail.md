# Apply report — `w3-jeeber-request-detail`

**Screen:** `jeeber-request-detail` (`/jeeber/requests/:id`, T-mobile-013 / T-MOB-FIX-001) — **no
render on the board**; language applied from its journey neighbour **17 offer composer**, which it
sits directly before (16 Jeeber home → *this* → 17 Offer composer).
**Files touched (4):**
- `lib/features/jeeber_request_detail/presentation/jeeber_request_detail_screen.dart`
- `lib/features/jeeber_request_detail/presentation/jeeber_request_detail_loader.dart` (loading view only)
- `lib/features/jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart`
- `test/jeeber_request_detail_summary_test.dart` (two widget-type pins retargeted + one added case)

**Status: done.** No shared-file edit, no new l10n key, no wiring request needed.

---

## 1. What the neighbour does, and what this screen did

**17 (measured from `17-offer-composer.png` / `.html`):** an **in-body header** — Ø40 tonal circle
+ navy `h2` title + a periwinkle subtitle line — over a top-aligned column at **24px gutters**.
Content is uppercase periwinkle `sectionLabel`s over **outlined r16 cards with no shadow**; the
inks are strictly ranked (navy = the fact, periwinkle = its qualifier); orange appears **exactly
once** as a text link (`Top up`); the bottom **~40% of the screen is plain white**; a single navy
pill is docked at the very bottom.

**This screen before:** a Material `OMDSAppBar` (elevation + surface tint + M3 `titleLarge` chrome)
over an `OMDSSectionCard`, whose rows were `_DetailRow`s built from a `primaryContainer`-filled Ø32
icon disc plus a raw `theme.textTheme.labelSmall` / `bodyLarge.copyWith(w600)` pair — label above
value, i.e. the qualifier ranked above the fact. Both CTAs were `OmdsPrimaryButton`s inside a flat
`EdgeInsets.all(24)` `Column`, and the summary `Expanded` let the (three-row) card sit in a body
that read as a form, not as a board screen.

## 2. Applied

| Change | Why |
|---|---|
| `Scaffold.appBar: OMDSAppBar` → in-body **`JeebTopBar.back`**, body stays in `SafeArea` | §5 #1 — the header is a body row on 17 of 24 screens. New id `jeeber_request_detail_back` per §7.5. Back stays **pop-guarded**: the kit's default is `Navigator.maybePop`, byte-equivalent to the `OMDSAppBar` default it replaces, so the cold-push-tap case behaves exactly as before |
| `OMDSSectionCard(title:)` → **`JeebSectionLabel`** + **`JeebOutlinedCard.grouped`** | §5 #10 + #3. The card title becomes the uppercase periwinkle band label above the card (17's `YOUR PRICE` / `PICKUP ETA` idiom); the card is 1.5px `outline` on white, r16, **no shadow** (R7) with the kit's inset 1px `outlineVariant` dividers |
| `_DetailRow` / `_DetailRowBadge` / `_DetailRowText` (3 private widgets, ~80 LOC) **deleted** → **`JeebListRow`** | §5 #25. Removes the raw `TextStyle` pair, the `primaryContainer` disc and the hand-rolled 32px badge. **Ink ranking flipped to R4**: the value is now the row *title* (navy w700) and the field name its *subtitle* (periwinkle) — the same shape 20 and 23 ship |
| Glyphs `shopping_bag_outlined` → `shopping_bag`, `adjust` → `place`, `confirmation_number_outlined` → `confirmation_number` | R10 — filled, single-colour, no outline variants anywhere on the board |
| Body gutters `EdgeInsets.all(24)` → `EdgeInsetsDirectional.fromSTEB(24, 20, 24, 24)` | §4.3 screen gutter; directional so it mirrors under RTL |
| Action `Padding`+`Column` of two `OmdsPrimaryButton`s → **`JeebCtaFooter.single`** with `JeebCtaButton.primary` + `below: JeebCtaButton.outline` | §5 #2. Docked padding `0/24/32`; the primary is the h56 navy pill with `ctaNavy`, the Decline becomes the 1.5px outline pill (the board's secondary treatment on 12/14) instead of a second filled button. **Order and destinations unchanged** |
| `jeeber-request-detail-make-offer` / `-decline` re-homed onto `JeebCtaButton.identifier` | The kit emits `Semantics(identifier:, button: true, container: true)` — the same node the hand-written wrapper emitted, so the frozen values are byte-identical and there is no longer a nested button node |
| **Loading view** (`jeeber_request_detail_loader.dart`) → same `JeebTopBar.back` | Its own doc comment states it mirrors the detail header "so the transition does not jump". Leaving it on `OMDSAppBar` would have *created* that jump. Spinner moved into an `Expanded`; `jeeber-request-detail-loading` unchanged |
| **Unavailable screen** → `JeebTopBar.back` + top-aligned scrollable empty state + `JeebCtaFooter.single(JeebCtaButton.primary)` | Same route surface, same OMDSAppBar problem. R1: the empty state was vertically `Center`ed — the board never centres, the residual space is deliberate. `jeeber_request_unavailable` and both `Key`s preserved |

### Deliberate judgment call (flagged, not hidden)
The unavailable screen previously had **no** leading affordance (`OMDSAppBar` without
`showBackButton`), and `JeebTopBar`'s `leading` is a mode, not a bool. Rather than hand-roll a
headerless variant, its circle is wired to `onLeadingPressed: onBack` — the **same edge the existing
"Browse other requests" CTA already owns**, so no new destination and no new behaviour class, just a
second entry to one that shipped. New id `jeeber_request_unavailable_back`.

**Not changed on purpose:** every string (no new l10n key — `jeeberRequestDetailRequestSection`
becomes the section label, `offerSubmissionTitle` stays the primary CTA label), the
`pushNamed('jeeber-offer-submission')` edge, the `onDeclined(request.id)` edge, the loader's four
resolution branches and its accepted-delivery redirect, the `reportService` constructor seam, and
the `friendlyReference(id)` rendering (`loader_test:82` asserts the raw id is never shown).

## 3. Data gap (§7.6)

`FeedRequest` carries **exactly three fields** — `id`, `shortLabel`, `description`. 17's tier chip
(`⚡ Flash`), items summary and money band have no source here, so the header subtitle slot and a
`JeebMoneyBreakdown` were **omitted, not faked**, with an in-file
`TODO(redesign-24)` naming the missing DTO fields. This is why the screen is three rows and a very
large white spacer: that emptiness is the board's own rule (R1), but it is emptiness by data
poverty as much as by design.

## 4. Constraints

- **Semantics:** `jeeber_request_detail_description`, `jeeber-request-detail-make-offer`,
  `jeeber-request-detail-decline`, `jeeber-request-detail-loading`, `jeeber_request_unavailable`
  all preserved byte-identically; `Key('jeeber-request-detail-summary')`,
  `Key('jeeber-request-unavailable-state')`, `Key('jeeber-request-unavailable-back-cta')` kept.
  New: `jeeber_request_detail_back`, `jeeber_request_unavailable_back` (§7.5 convention).
  Grepped repo-wide: **no Maestro flow references any of these** — the risk was tests only.
- **RTL:** every inset is `EdgeInsetsDirectional`; the back glyph, the row layout and the dividers
  come from the kit's directional implementations. The `ar` locale cases in the summary test pass.
- **Text scale:** a docked stack of two fixed-height pills is the realistic overflow risk here, so a
  **200% text-scale case was ADDED** to the summary test (passes, no exception).
- **D-decisions:** none apply — no money wording (D41/D44), no rating (D56), no KYC (D52), no
  vehicle keys (D20). No refusal was necessary.
- **No pubspec edit, no theme edit, no kit edit, no `lib/l10n` edit, no router/DI edit.**

## 5. Verification

- `dart analyze lib/features/jeeber_request_detail test/jeeber_request_detail_summary_test.dart test/features/jeeber_request_detail` → **No issues found.**
- `flutter test test/jeeber_request_detail_summary_test.dart` → **8/8 pass** (7 pre-existing + the
  new 200% case).
- `flutter test test/features/jeeber_request_detail/` → **12/12 pass** (loader's 8 branches +
  unavailable ×2, untouched assertions).
- `flutter test test/core/router/jeeber_request_detail_route_test.dart` → **2/2 pass** when run
  before the KYC lane's in-flight edit. ⚠️ A later re-run failed to **compile** on
  `lib/features/kyc/presentation/kyc_status_view.dart:364/420/709/774/823`
  (`Member not found: 'xxLarge'`, `Required named parameter 'iconTint'`) — that file is screen 22's
  lane, mid-edit, and the router test transitively imports it. **Not this lane's damage**; nothing
  in `lib/features/jeeber_request_detail` is involved.
- `flutter test test/core/router/back_nav_all_routes_test.dart test/notification_dispatcher_test.dart`
  → **70/70 pass** (the route's `RootAwareBackScope` contract is unaffected — it listens for system
  BACK, not the header button).
- `flutter test test/semantics_identifier_surfacing_test.dart` → **13/13 pass.**
- `tool/check_design_tokens.sh` → 3 violations repo-wide, **none in this lane's directory**
  (`client_location_screen.dart`, `wallet_activity_list_screen.dart`, `reviews_list_screen.dart` —
  pre-existing, other lanes).

### Test edits (two assertions retargeted, nothing weakened)
`test/jeeber_request_detail_summary_test.dart` pinned two OMDS widget **types**, which is exactly
what the migration changes:
- `find.byType(OMDSSectionCard) == 1` → `find.byType(JeebOutlinedCard) == 1` **and**
  `find.byType(JeebSectionLabel) == 1`. The claim ("the summary is a card, not loose text") is
  unchanged and is now two assertions, not one.
- `find.byType(OmdsPrimaryButton) == 2` → `find.byType(JeebCtaButton) == 2`, **plus** two new
  `find.bySemanticsIdentifier` assertions on the CTA ids the old test never checked.

No identifier was renamed and no gate was relaxed; both edits are strictly stronger than what they
replace.

## 6. Remaining inconsistencies vs 17 (self-critique)

1. **No orange anywhere.** 17 spends its single orange on the `Top up` link; this screen has no
   decaying value, no wallet strip and no live state to mark, so it is entirely navy/periwinkle.
   R5 would allow the `Send your offer` CTA to be the one orange fill (16 does exactly that on its
   freshest feed card) — but nothing on `FeedRequest` says *this* request is the freshest, so an
   orange pill here would be decoration, not information. Navy, matching 17's own send CTA.
2. **No header subtitle.** 17's `ORD-9C37B6 · Pharmacy run · ⚡ Flash` is the strongest single
   signal that these two screens are the same product. The reference is on this screen, but as the
   third card row (a test pins its visible `Request reference` label, and pulling it into the
   subtitle would leave a two-row card). Once the feed DTO carries tier + items, that line should
   move up.
3. **The footer is two pills tall (56 + 10 + 50).** No board screen docks a stacked pair; the
   closest is 12's `split` (text + outline, side by side). Keeping the stack preserves the existing
   affordance weighting, but it is visually heavier than anything drawn.
4. **The card is only three rows** against 17's four content blocks, so the white spacer is larger
   than any board screen's. Correct per R1, but it reads as sparse rather than as restraint.
5. **`OmdsEmptyState` on the unavailable screen is still OMDS-internal** — its icon size and text
   ramp come from OMDS, not `context.jeebText`. Re-skinning it means either an OMDS edit (forbidden)
   or hand-rolling the empty state, so its chrome is on-system and its interior is not.
6. **`JeebListRow` renders a long description at 14/w700 navy.** For a 2–3 line paragraph that is
   heavier than `jeebText.body` would be. Left on the kit default rather than passing a
   `titleStyle` override, so the three rows stay one visual family.
