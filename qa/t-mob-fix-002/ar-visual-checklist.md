# AR Visual Rendering Checklist — T-MOB-FIX-002

**Owner of execution**: QA-POST (`JEB-226`)
**Owner of authoring**: QA-PRE (`JEB-225`) — this file
**Source**: JEB-2 comment `14779` §5 (UX) + comment `14782` §5 (Tech Lead AC2 rewrite)
**Trigger**: every PR opened by ENG (`JEB-227`) on branch `feature/jeeb-v3-l10n-restore-156-keys` (or per-feature `*-1a..*-1f` sub-PRs)
**Locale under test**: `ar-LB` (Levantine Arabic, Lebanon)

---

## Test matrix (12 cells)

Run every checklist item below on every cell.

| Cell | Device class | Viewport | DPR | Locale | Numeral system | Build |
|---|---|---|---|---|---|---|
| C1 | Pixel 4a (Android) | 360 × 640 | 2.75× | `ar-LB` | Western (`0–9`) | ENG PR build |
| C2 | iPhone SE 1st-gen (iOS) | 320 × 568 | 2.0× | `ar-LB` | Western (`0–9`) | ENG PR build |
| C3 | Pixel 4a | 360 × 640 | 2.75× | `en-US` | Western (`0–9`) | ENG PR build (regression smoke) |
| C4 | iPhone SE 1st-gen | 320 × 568 | 2.0× | `en-US` | Western (`0–9`) | ENG PR build (regression smoke) |

Cells C1+C2 are the **strict AR gate** (AC2). C3+C4 are EN regression smoke — they MUST stay green to prove the EN baseline didn't break.

---

## Affected screens inventory

Per LEAD §6, the six feature roots and a representative screen per root. QA-POST runs the checklist on each.

| # | Feature root | Representative screen | Restoration commit (LEAD §6) |
|---|---|---|---|
| F1 | `lib/features/jeeber_home/` | Jeeber home tab | `4563aa0` (T-mobile-037) |
| F2 | `lib/features/settings/` | Settings screen + sign-out confirmation dialog | `b56e925` (T-mobile-031) |
| F3 | `lib/features/delivery_status/` | Active delivery card | `902d91e` (T-mobile-018) |
| F4 | `lib/features/availability/` | Availability toggle + inactivity warning banner | `2cb24f0` (T-mobile-027) |
| F5 | `lib/features/chat/` | Chat composer + active-delivery title | `503af40` (T-mobile-016) |
| F6 | `lib/features/order_history/` | Order history list | `475451f` (T-mobile-030) |

Plus three additional surfaces called out by UX:
- Bottom-navigation bar (all 6 tabs visible) — every cell.
- AppBar across all 6 feature roots — every cell.
- Earnings summary (lives under jeeber_home but covered separately because of plural sets).

---

## The 11-item visual defect checklist

For each (cell × screen) tuple, run the checks below. Each row records **PASS / FAIL / N/A** with evidence reference (`.maestro/baselines/ar-LB/<viewport>/<feature>.png` for the AR build; PR-comment screenshot link for ad-hoc).

### V1 — No literal `<key>` placeholder
**Check**: no rendered text node displays the literal key string (e.g. the screen does NOT show `appBarSignOut` instead of "تسجيل الخروج").
**Implementation**: Maestro `assertNotVisible` against the union of `S2` getter names (loaded from `_artifacts/s2_getters.txt`). For ad-hoc visual: scan screenshot for camelCase Latin tokens.
**Source**: UX §5 item 10; LEAD AC2 rewrite item 1.

### V2 — No Latin-fallback in AR rendered strings
**Check**: when locale is `ar-LB`, no text node in the AR build contains the Latin key name as a fallback. Specifically the runtime parity test (`test/l10n/runtime_parity_test.dart`) asserts `l.byKey(k) != k` for every `k ∈ S4`; this visual gate is the screenshot-OCR backstop.
**Implementation**: Maestro screenshot + OCR (or visual review) on AR screens — reject any frame containing the regex `\b[a-z][a-zA-Z0-9_]{3,}\b` outside brand tokens (`Jeeb`, `Jeeber`) and numerals.
**Source**: UX §5 item 10; LEAD AC2 rewrite item 2.

### V3 — Bottom-nav AR labels do not clip mid-glyph
**Check**: all 6 bottom-nav tab labels in AR render fully visible within their tab; no ellipsis on a single line, no mid-glyph clipping. Labels are right-aligned within their tab.
**Watch-list keys**: `navHome` (`الرئيسية`, 4.0× chars), `navOrders` (`طلباتي`, 2.0× chars), `navDashboard`, `navEarnings`, `navChat`, `navProfile`.
**Source**: UX §5 item 2; UX §1 length-expansion table; LEAD AC2 rewrite item 3.

### V4 — AppBar title fits without single-line ellipsis on every restored-key screen
**Check**: for each screen in F1–F6, the AppBar `Text(l10n.<screenTitle>)` renders without `…` truncation on a single line at both 320×568 and 360×640.
**Watch-list keys** (from current ARB): `availabilityHomeTitle` (`متاح للعمل`), `chatActiveDeliveryTitle`, `homeRefreshHint`, `earningsBreakdownTitle`.
**Source**: UX §5 item 3; LEAD AC2 rewrite item 3.

### V5 — `OmdsConfirmationDialog` renders AR `confirmText` + `cancelText` side-by-side without wrapping
**Check**: the sign-out / delete-account / discard-changes dialogs render their two buttons on a single horizontal line at both viewports. **Cancel button is on the LEFT in AR** (RTL puts the destructive/primary action at the visual-trailing edge).
**Watch-list locations**: `settings_screen.dart:324`, `:340`; account-delete flow.
**Source**: UX §5 item 4; LEAD AC2 rewrite item 4.

### V6 — `OmdsSettingsRow` chevron / leading icon mirror correctly
**Check**: in AR, `OmdsSettingsRow`'s trailing chevron points LEFT (was right in LTR); leading icons of nav rows similarly mirror; back arrow on every AppBar points right (the RTL way back).
**Watch-list locations**: `settings_screen.dart:313`; every AppBar back affordance; chat send button.
**Subtitle**: the two-line subtitle cap holds for AR `accountDeleteSubtitle`, `accountDeletePending` (no clipping at the second-line boundary).
**Source**: UX §5 items 5, 6; LEAD AC2 rewrite item 4.

### V7 — `chat_composer` `composerHint` not truncated mid-word in AR; send button on visual-trailing edge
**Check**: AR placeholder text inside the chat input never truncates mid-Arabic-word; send button visually anchors to the LEFT (RTL trailing).
**Source**: UX §5 item 6.

### V8 — Every `Text(l10n.*)` call site in restored paths uses Material text theme (proper AR font)
**Check**: AR text renders in a glyph-complete AR font (`GoogleFonts.cairoTextTheme()` or OMDS-Flutter equivalent); no Roboto fallback (its AR fallback glyphs are unreadable). Visual cue: if AR text looks like rectangles or boxy substitutions, V8 fails.
**Implementation**: ENG attests in PR description that no `TextStyle(fontFamily: 'Roboto')` is added or retained in restored code paths.
**Source**: UX §5 item 7; LEAD §5 font paragraph; skill `flutter-material3-colorscheme-discipline`.

### V9 — `SnackBar` content wraps cleanly in AR; no horizontal scroll
**Check**: error/status SnackBars (e.g. `availabilityToggleErrorBody` at `jeeber_home_screen.dart:69`) wrap to additional lines as needed, but NEVER overflow horizontally.
**Source**: UX §5 item 8; LEAD AC2 rewrite item 6.

### V10 — Numeral system is Western (`0123456789`) in AR strings
**Check**: numbers inside AR strings (ETAs, counts, currency) render with Western digits, NOT Eastern Arabic digits (`٠١٢٣٤٥٦٧٨٩`). Locked decision per LEAD §5.
**Watch-list**: `homeRequestEtaMinutes('{minutes}')`, `earningsSummaryCompletedOther`, anything ending in `Count` / `Minutes` / `Items` / `Orders`.
**Override clause**: only PO can override via JEB-2 comment; absent that, Eastern digits = FAIL.
**Source**: UX §5 item 9; LEAD §5.

### V11 — Inactivity warning banner (`inactivity_warning_banner.dart`) title + CTA both fit; CTA does not overflow
**Check**: at both viewports in AR, the banner's title and CTA button both fully render; the CTA does not overflow its container or wrap to a second line.
**Watch-list keys**: `availabilityInactivityWarningTitle`, `availabilityInactivityWarningBody`, `availabilityInactivityWarningCta`.
**Source**: UX §5 item 11; LEAD AC2 rewrite item 7.

---

## Cross-cutting bidi check (informational; failures roll up to V4/V7)

Mixed-direction segments must use Unicode FSI/PDI (U+2068 / U+2069). ENG wraps brand tokens, ETAs, currencies, and phone numbers in `⁨…⁩` inside the AR ARB. QA-POST verifies visually: brand "Jeeb" / "Jeeber", `{minutes}`, `{amount}` placeholders render in the correct visual position within the AR sentence (numerals on the right edge of the embedded LTR run, not flipped into the AR run).

**Reference**: UX §1 item "Mixed-direction segments"; LEAD AC2 rewrite item 5.

---

## QA-POST reporting format (per cell × screen)

```
[T-MOB-FIX-002][QA-POST] cell=<C1|C2|C3|C4> screen=<F1..F6|nav|appbar|earnings>
V1=<PASS|FAIL>  V2=<PASS|FAIL>  V3=<PASS|FAIL>  V4=<PASS|FAIL>  V5=<PASS|FAIL|N/A>
V6=<PASS|FAIL>  V7=<PASS|FAIL|N/A>  V8=<PASS|FAIL>  V9=<PASS|FAIL|N/A>
V10=<PASS|FAIL>  V11=<PASS|FAIL|N/A>
Evidence: <screenshot path or PR-comment URL>
```

Any single FAIL on a strict-AR cell (C1 or C2) blocks AC2. N/A is acceptable when the screen does not exercise that surface (e.g. F6 order-history has no SnackBar in the happy path; V9 = N/A).

---

## Maestro flow scaffolding (handoff to QA-POST)

QA-POST authors the executable Maestro flows on top of this checklist. Suggested file layout:

```
.maestro/
  l10n-ar/
    _runner.yaml                 # iterates cells C1..C4 × screens F1..F6 + nav/appbar/earnings
    _common/
      launch-ar.yaml             # locale=ar-LB, viewport=320x568 OR 360x640
      launch-en.yaml             # locale=en-US (regression smoke)
    flows/
      f1-jeeber-home.yaml
      f2-settings.yaml
      f3-delivery-status.yaml
      f4-availability.yaml
      f5-chat.yaml
      f6-order-history.yaml
      common-bottom-nav.yaml
      common-appbar.yaml
      common-earnings.yaml
    baselines/
      ar-LB/
        320x568/<feature>.png
        360x640/<feature>.png
      en-US/
        320x568/<feature>.png
        360x640/<feature>.png
```

Reference skills: `maestro-page-object-via-runflow`, `maestro-flow-yaml-patterns`, `flutter-l10n-rtl-arabic`.

---

## Notes for QA-POST (`JEB-226`)

- Do NOT block on V10 if PO has explicitly overridden via a comment on `JEB-2` that authorizes Eastern Arabic digits. Otherwise V10 is strict.
- For V2 (Latin-fallback), the runtime parity test in `test/l10n/runtime_parity_test.dart` is the authoritative gate. The visual OCR check is a backstop, not a replacement.
- V8 cannot be detected from screenshots alone if the AR font happens to ship as a Roboto-Arabic fallback that *does* contain glyphs — confirm via the PR diff that `Theme.of(context).textTheme.<role>` is used (skill `flutter-material3-colorscheme-discipline`).
- V5's "Cancel on the left in AR" is sometimes mis-implemented as "Cancel on the right because we copied the LTR layout". Verify by toggling locale at runtime and confirming the buttons SWAP, not just text-translate.
- If the ENG PR is split into per-root sub-PRs (`ENG-1a..ENG-1f`), QA-POST runs the corresponding subset of F1–F6 per sub-PR plus a full nav/appbar smoke against the merged base after each sub-PR lands.
