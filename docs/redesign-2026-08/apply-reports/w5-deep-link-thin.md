# W5 — deep-link-thin

**Status: `no-change-needed`. Zero files changed.**

## One-line justification

Both files are frozen "coming soon" placeholders whose entire body is a single theme-driven
`OmdsEmptyStatePage` — no literal, no bespoke widget and no spacing decision exists at the call-site
to re-skin, both routes are unreachable in production, and both are the last two files still passing
the `placeholder-discipline.sh` gate 11/11, which a re-skin would break by construction.

## Scope

| File | Verdict |
| --- | --- |
| `lib/features/deep_link_targets/kyc_status_screen.dart` | no change |
| `lib/features/deep_link_targets/rating_prompt_screen.dart` | no change |

## Evidence

**1. There is nothing to re-skin. Neither file makes a single visual decision.**
The two files are 37 and 47 lines. A grep for `Color(` · `Colors.` · `TextStyle` · `EdgeInsets` ·
`BorderRadius` · `Padding` · `SizedBox` · `Card` · `Container` · `Row` · `Column` over both returns
**nothing**. Each `build` is one `Semantics(container:, label:)` wrapping one
`OmdsEmptyStatePage(icon:, title:, subtitle:)` — every pixel is delegated. There is no hardcoded hex
to tokenise, no card to swap for `JeebOutlinedCard`, no 24px gutter or 28px rhythm to correct, no
radius to soften, no shadow to trade for an outline, and no `Semantics(identifier:)` anywhere to
preserve (both use `label:`, not `identifier:` — left byte-identical regardless).

**2. What they render is *already* on the Wave 0 palette.**
`OmdsEmptyState` (`omds-flutter/omds_library/lib/src/feedback/omds_empty_state.dart:73-119`) styles
exclusively from `Theme.of(context).colorScheme` / `textTheme` — zero literals. Since Wave 0 set
`onSurface: #0B0E53` and `onSurfaceVariant: #5C4038` (`lib/core/theme/app_theme.dart:62,107,155-156`),
these screens already draw a navy-ink title and a muted subtitle/icon on white. They inherit the
redesign; they are not stranded on an old palette.

**3. Both routes are dead in production — this is not a user-facing surface.**

- `kyc_status_screen.dart`: `/profile/kyc` builds **`KycWizardScreen`**, not `KycStatusScreen`
  (`lib/core/router/app_router.dart:895-906`, "E-P0 fix: the old `KycStatusScreen` was a read-only
  status stub … Surface the real wizard instead"). Outside its own file the class name appears in
  `lib/` exactly once, in the devtool catalog (`lib/devtool/catalog/entries/batch_03_entries.dart:137`).
  It carries an `ORPHAN (JEBV4-227, verified 2026-07-12)` header.
- `rating_prompt_screen.dart`: `/orders/:id/rate` carries an unconditional `redirect` to
  `/orders/:id/mutual-rate` that fires for every non-empty id (`app_router.dart:864-884`); the
  builder is retained only "as an unreachable fallback". `test/core/router/integration_wiring_test.dart:134-160`
  **asserts** `find.byType(RatingPromptScreen)` → `findsNothing` and
  `find.text('Rating Prompt coming soon')` → `findsNothing`. Also `ORPHAN (JEBV4-227)`.

**4. A re-skin would break a live gate and contradict both files' own contracts.**
`qa/t-mob-fix-001/placeholder-discipline.sh` lists both under `TYPE_A_FILES` (lines 27-28). Running
it today, these two are the **only** files in `lib/features/deep_link_targets/` still scoring 11/11
PASS — the redesigned siblings already fail rules B/C/D/F, having legitimately outgrown the template
via real feature work. Applying the kit here would trip:

- **Rule B** — dropping `OmdsEmptyStatePage` for `JeebOutlinedCard`/`JeebCtaFooter`.
- **Rule D** — routing the copy through `AppLocalizations` (which hard constraint 4 would otherwise
  require, since the strings are user-visible English literals). The two rules are in direct
  opposition; the file headers resolve it explicitly.

`rating_prompt_screen.dart:4-10` states the full UI "ships only after the CI gate is lifted (this
file removed from `TYPE_A_FILES`) … do NOT add behavior, action buttons, loading indicators,
dialogs, snackbars, or l10n hooks here". It has **not** been removed from `TYPE_A_FILES`. Lifting
that gate is `T-MOB-RATING-001`'s deliverable, not a re-skin wave's.

## Neighbour comparison (`15-mutual-rating.png`)

Re-viewed after the assessment. The render's language is a stacked band composition — navy avatar
with a rationed orange status dot, periwinkle meta line, star row, a `WHAT STOOD OUT?` section label
over an outlined/navy-filled chip wrap, a grey note field at 16px radius, an orange-outlined info
note, and a full-bleed navy CTA pinned at the bottom over a 24px gutter with a 999px pill radius.
**None of those bands has a counterpart in a 3-element empty state**, and inventing them would mean
inventing a KYC-status UI and a rating UI that no board covers, no endpoint backs, and — for the
rating route — that already exists one redirect away as the redesigned `MutualRatingScreen`. The
correct fix for "this looks like a different product" on `/orders/:id/rate` is the redirect, and it
is already in place: a real user is never shown this screen.

## Siblings in this directory

`delivery_detail_screen.dart` and `chat_detail_screen.dart` are genuinely redesigned — they import
`jeeb_text_styles.dart` plus `JeebOutlinedCard` / `JeebCtaButton` / `JeebCtaFooter` / `JeebInfoNote`
/ `JeebListRow` / `JeebTopBar` (18 and 61 `Jeeb*` references). The difference is not neglect: those
two are 28KB and 97KB of real, routed, network-backed UI. Mine are 1.1KB and 1.8KB of unrouted
stub. Matching their *treatment* is only meaningful where there is content to treat.

## Deferred / not touched

- The English literals `'KYC Status coming soon'`, `'This screen is not yet available.'`,
  `'Rate your Jeeber'` and `'Rating Prompt coming soon'` are unlocalised. Fixing that is Rule D's
  own scope note (`T-MOB-FIX-002`) and needs the discipline gate lifted first — flagged, not
  changed. No wiring request filed, because no ARB key should be added for copy that is scheduled
  for deletion with the placeholder.
- Whoever lands `T-MOB-RATING-001` / the KYC-status follow-up should remove both paths from
  `TYPE_A_FILES` in the same PR that puts the kit into these files; that is the point at which this
  lane's work becomes possible, and it is a feature ticket, not a re-skin.

## Verification

No code changed, so the baseline is untouched by construction: analyze 0 errors, `flutter test`
4664 pass / 61 skip / 1 pre-existing fail (`gesture_log_test`, local-SDK skew, green in CI).
`bash qa/t-mob-fix-001/placeholder-discipline.sh` still reports both files 11/11 PASS.
