# w3 — `escalate` (dispute-open-evidence) onto the Jeeb design system

**Target:** `lib/features/escalate/presentation/escalate_screen.dart` (the whole lane; the
`application/`, `data/` and `domain/` layers were not touched).
**Reference:** none — this is one of the 46 screens the 24-screen board never drew. Language taken
from **21 `order-chat`**, the screen it is opened from (`order_chat_open_dispute`), plus the two
already-migrated house screens `order_history_screen.dart` and `wallet_hub_screen.dart`.

**Status:** shipped. `dart analyze lib/features/escalate` → *No issues found*.
`flutter test test/escalate_screen_test.dart test/escalate_cubit_test.dart test/features/escalate`
→ **20/20 pass** (unchanged). `tool/check_design_tokens.sh` reports zero violations in this lane
(the 3 it reports are `location/` and `wallet/`, other lanes).

---

## 1. What 21 does, and what this screen was doing instead

| 21 `order-chat` | `escalate` before |
|---|---|
| In-body header row: Ø40 tonal back circle at the 24px gutter, identity block, Ø40 trailing circle | `OMDSAppBar` — a Material app bar with a centred title, and it existed **only** in the input phase (submitting/error rendered a bare body) |
| 24px side gutters everywhere; blocks at 10–18px rhythm | `EdgeInsets.all(Spacing.medium)` — a 16px gutter, 8px narrower than every migrated neighbour |
| Navy used once, as a whole surface (the order strip) and as the outgoing bubble fill | Navy only as a `ListTile` radio tick; no navy surface anywhere |
| Orange rationed to a single Ø8 dot | No orange at all |
| Outline-over-shadow: brown 1.5px pills, flat grey blocks, radii 999/18/14 | Stock `ListTile` rows (no shape at all) + one `surfaceContainerHighest` `Container` at `OmdsBorderRadius.medium` |
| Type is an explicit ramp (17/w700 name, 13.5 body, 11.5/w600 meta) | `theme.textTheme.bodyMedium` / `titleSmall` / `labelLarge` — stock M2021, no ramp |
| Docked bottom band, pad `10/24/30` | `Padding(EdgeInsets.all(Spacing.large))` + a hand-built `Row` |

The screen read as a different product: a 16px-gutter Material form hanging off a Material app bar,
sitting one tap away from a 24px-gutter navy-and-outline chat.

## 2. What changed

**Structure**
- `Scaffold(appBar: OMDSAppBar)` → `Scaffold(body: SafeArea(Column[JeebTopBar, Expanded(...)]))`.
  The header is now an in-body row (21's shape) so it renders in **all three phases** —
  submitting and error previously had no header at all.
- `_BottomBar`'s hand-built `Row` → `JeebCtaFooter.split` (docked `0/24/32`), leading
  `JeebCtaButton.outline(expand: false)`, trailing `JeebCtaButton` primary. Same two buttons, same
  order, same proportions (back intrinsic, submit filling).
- Body gutters `16` → `EdgeInsetsDirectional.fromSTEB(24, 16, 24, 24)`; block rhythm
  `Spacing.large` (20) between top-level blocks, `Spacing.small` (12) after each section label.

**Kit widgets adopted** (9): `JeebTopBar` · `JeebSectionLabel` ×3 · `JeebOutlinedCard` ×7 ·
`JeebInfoNote` ×2 (`muted`, `error`) · `JeebCtaButton` ×5 (`primary`, `outline` ×3, `text`) ·
`JeebCtaFooter.split` · `JeebSelectChip` + `JeebChipRow.scrollable`.

- **Reason picker** — six `ListTile`s with radio glyphs → six `JeebOutlinedCard`s. Unselected =
  white + 1.5px brown outline; selected = the card's `JeebCardState.selected`, i.e. a solid navy
  fill (one state machine with `JeebNavySurfaceCard`, so the rows cannot jitter and the navy cannot
  drift). Selection mark = accent `check_circle` — the rationed orange, a mark on navy, never a fill.
  Label moved to `context.jeebText.cardTitle`.
- **Auto-attach note** — a bare `Row(Icon, Text)` → `JeebInfoNote.muted(icon: attachment)`.
- **Photo chips** — `OmdsChip` (8px-rect chip theme) → `JeebSelectChip(role: inlineAction,
  selected: true)` inside `JeebChipRow.scrollable`, with a `close` glyph in the `leading` slot.
  `Wrap` → scrollable row so five attachments stay on one line and the trailing gutter scrolls.
- **Add-photo / voice CTAs** — `OMDSOutlinedButton` → `JeebCtaButton.outline` (pill, 1.5px outline,
  no shadow). Voice glyphs moved to filled variants (R10): `mic`, `stop_circle`.
- **Photo/permission error** — red `bodySmall` text → `JeebInfoNote.error` (the kit's error tone
  keeps its role colour on every surface).
- **Evidence card** — `Container(surfaceContainerHighest, OmdsBorderRadius.medium)` →
  `JeebOutlinedCard`; its rows are a new private `_EvidenceLine` (filled glyph 16px + `jeebText.bodySmall`
  in `onSurfaceVariant`).
- **Support link** — `TextButton.icon` → `JeebCtaButton.text(expand: true)`. The frozen
  `Semantics(identifier: 'dispute_support_link', onTap:) + ExcludeSemantics` wrapper is byte-identical:
  the full-width target the 68_W34 closeout required is preserved (`expand: true`), and the label is
  now centred, so the Maestro node-centre tap lands **on** the label rather than beside it.

**Tokens** — every `theme.textTheme.*` replaced with `context.jeebText.*`
(`cardTitle` / `bodySmall` / `body`); accent read from `context.jeebRoles.accent`; inks from
`colorScheme` roles (`onPrimary` on navy, `onSurface`, `onSurfaceVariant`, `outline`, `primary`).
Zero `Color(0x…)`, zero raw `TextStyle(`, zero `fontSize:`. No shadow anywhere (outlined cards
never carry one).

**RTL** — all insets `EdgeInsetsDirectional`; verified by rendering the full form (5 attachments,
selection, loaded evidence) in `ar` with no exceptions.

## 3. What deliberately did NOT change

- **Behaviour, navigation, business logic, block order, phase machine** — identical. Same four
  edges (`dispute-status`, `support-ticket`, pop→`shell`, `submit`), same `canSubmit` gate, same
  D53 `loadEvidence()` post-frame call, same photo/voice seams and their permission handling.
- **All 11 `Semantics(identifier:)` nodes byte-identical**, flags included: `dispute_root`,
  `dispute_auto_attach_note`, `dispute_reason`, `dispute_reason_<name>` ×6, `dispute_photos`,
  `dispute_photos_add_cta`, `dispute_photos_chip_<i>`, `dispute_voice`, `dispute_comment_field`,
  `dispute_evidence_timeline`, `dispute_evidence_chat`, `dispute_support_link`, `dispute_back`,
  `dispute_submit_cta`, `dispute_error`. Every kit widget is nested **inside** the existing wrapper
  and given no `identifier` of its own, so no kit `container/explicitChildNodes` node replaces a
  frozen one.
  → Consequence: **`JeebTopBar` gets no `identifier`.** The kit's contract is
  `identifier` → `<screen>_back`, but `dispute_back` is already the frozen id of the footer's
  "Back to chat" button. The header circle is left un-identified (exactly as the `OMDSAppBar` back
  button was). See §5.
- `OmdsTextField` (comment), `OmdsLoadingState`, `OmdsErrorState` — the kit has no input, loading or
  error primitive; `wallet_hub_screen.dart` keeps the same three.
- **No pubspec edit, no l10n edit, no shared-file edit.** Nothing was blocked;
  `docs/redesign-2026-08/wiring/w3-escalate.md` carries two non-blocking copy requests.

## 4. The one content change, and why

`escalateSubtitle` ("Describe what went wrong and we'll connect you with our support team within 24
hours.") was rendered **three** times: as a bare lede paragraph, then **immediately beneath it,
verbatim**, inside `dispute_auto_attach_note`, then again as the evidence card's header.

The two adjacent copies are collapsed into one — the `dispute_auto_attach_note` info note now
carries the lede itself, in the same position, with the same identifier and the same sentence. No
affordance removed, no meaning changed, one duplicated paragraph deleted. The third (the evidence
card header, ~400px lower) is left standing; removing it would leave the card untitled and that
needs a new string, requested as R2 in the wiring file. Grepped first: no test, no Maestro flow and
no other lane references this string (`maestro/` does not exist in the repo).

## 5. Known remaining inconsistencies

See `selfCritique` in the lane's structured output — the substantive ones are: the OMDS comment
field still reads as stock Material next to the kit; the header back circle is not Maestro-tappable
(id collision, pre-existing); the section labels uppercase sentence-shaped copy
("PHOTOS (OPTIONAL, UP TO 5)"); `'Photo N'` is still an English literal; and six full-width reason
cards is a lot of vertical weight for a picker.
