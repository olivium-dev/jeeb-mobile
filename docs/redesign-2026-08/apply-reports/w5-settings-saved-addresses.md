# W5 — settings-saved-addresses

**Status: `no-change-needed`. Zero files changed.**

## One-line justification

`saved_addresses_screen.dart` is a 36-LOC `ORPHAN`-tagged "coming soon" placeholder that no route
mounts — the live `/settings/addresses` surface is `SavedLocationsScreen`, and **it was already
brought onto the design system on this branch** — so re-skinning the dead copy would produce a second
visual language for a screen no user can reach.

## Scope

| File | Verdict |
| --- | --- |
| `lib/features/settings/presentation/screens/saved_addresses_screen.dart` | no change |

## Evidence

**1. It is a tagged orphan of exactly the class Constraint 10 forbids touching.** Line 6 carries
`// ORPHAN (JEBV4-227, verified 2026-07-12): superseded by SavedLocationsScreen (T-MOB-025)`, written
by commit `386c743c docs(code): orphan header comments on 27 unrouted classes (JEBV4-227)`. That is
the *same tag from the same commit* as `live_settings_screen.dart`, which my constraints name as
NEVER TOUCH, and which `screen-repo-map.md` line 18 independently flags as
*"itself tagged `ORPHAN (JEBV4-227)` with nothing navigating to it."* Lines 4–5 add an explicit
contract: *"Placeholder restored under T-MOB-FIX-001 … Do NOT add behavior here."*

**2. It fails the migration plan's own reachability sanity rule.** The 🛑 STOP block says
*"confirm your file is reachable from `lib/main.dart` before editing it"* and disqualifies screens 08
and 09 for having only a **devtool-only importer**. A whole-repo grep for `SavedAddressesScreen`
returns four hits inside the file itself plus exactly one importer —
`lib/devtool/catalog/entries/batch_10_entries.dart:669` — the devtool catalog. No router, no shell
tab, no test, no Maestro flow references it. It shares the placeholder header with
`location_picker_screen.dart`, one of the three files I am explicitly barred from editing.

**3. The route was reassigned, and the real screen is already redesigned.** `app_router.dart:1024`
mounts the `settings-addresses` route on `SavedLocationsScreen`, under the in-code note
`// T-MOB-025: replace placeholder with the real CRUD screen.` — the replacement already happened.
That live screen imports **six** kit widgets:

    jeeb_cta_button · jeeb_cta_footer · jeeb_list_row · jeeb_outlined_card ·
    jeeb_system_chip · jeeb_top_bar

landed in `d44c0945 feat(redesign): bring the remaining uncovered screens onto the design system` —
the head commit of this branch. My lane note said *"use `JeebListRow` for the address rows"*; that is
already done, on the file users actually see, by the location lane. Doing it again here duplicates
shipped work on a dead file.

**4. There is nothing left to re-skin, and what renders is already token-correct.** The entire
`build` is one `OmdsEmptyStatePage` wrapped in a `Semantics(container:label:)`. The file contains no
`Color(`, no `TextStyle`, no `EdgeInsets`, no `BorderRadius`, no `Scaffold`, no `Card`, and — worth
stating because Constraint 1 turns on it — **no `Semantics(identifier:)` at all**, so there is no
identifier to preserve or to add (there is no interactive widget). Upstream,
`omds-flutter/omds_library/lib/src/feedback/omds_empty_state.dart` has **zero** hardcoded colours, so
the placeholder already inherits the Wave 0 palette through the theme. There is no hex to tokenise
and no bespoke card to swap.

**5. Re-skinning it would force an l10n wiring request for unreachable copy.** The only two
user-visible strings — `'Saved Addresses coming soon'` and `'This screen is not yet available.'` —
are hardcoded English. Any redesign that touches the empty state trips Constraint 4: new `app_en.arb`
+ `app_ar.arb` keys **plus** an edit to the hand-authored parser in `lib/l10n/app_localizations.dart`,
i.e. a `wiring/w5-*.md` request against a shared file, spent on copy that no navigation path can
display. Leaving it is strictly cheaper and strictly safer.

## Neighbour comparison (`20-settings.png`)

Re-viewed after the assessment. The render's language is unmistakable and I checked my file against
every band of it: navy `#0B1351` profile card at the top, one rationed-orange outlined
"Become a Jeeber" row (orange as a 2px frame and a text CTA, never a fill), periwinkle `#777FC0`
all-caps section labels (`LANGUAGE`, `NOTIFICATIONS`), outlined white cards with hairline dividers
and **no** shadow, 999px pill radii for the toggle track and segmented control against 16px card
radii, 24px gutters, and a footer stack of outlined `Sign out` over a bare red `Delete account`.

My file has **none of these bands to map onto** — it is a centred icon, a title and a subtitle in the
dead centre of an otherwise empty page. There is no list to make a `JeebListRow`, no section to label
with `JeebSectionLabel`, no header to make a `JeebTopBar` (it passes `appBar: null`), no CTA to make
a `JeebCtaButton`. Applying the render's structure would mean *inventing* a saved-addresses UI —
flow and content invention, not a re-skin, and a direct violation of "no invented endpoints, fields or
contracts" and of the file's own "Do NOT add behavior here".

The one thing the comparison did confirm: the live `SavedLocationsScreen` already reads as a sibling
of this render (outlined rows, `JeebSystemChip` for the default badge, `JeebCtaFooter`), so the
journey has no visual seam at `/settings/addresses` today.

## Deferred / not touched

- **`notification_preferences_screen.dart`** (same directory, routed at `app_router.dart:1044`) is
  the detail screen behind the render's `NOTIFICATIONS` band. It has **0** raw hex — so it is
  theme-correct and not broken — but also **0** `jeebText` / `jeebRoles` / `JeebShadows` usages and
  no kit imports, so it has not been brought onto the Jeeb layer the way `settings_screen.dart` and
  `profile_edit_screen.dart` have. It was not in this lane's assigned file list; flagged for whoever
  picks up the remaining settings surfaces, not changed here.
- `live_settings_screen.dart` — untouched per Constraint 10.
- The devtool catalog entry at `batch_10_entries.dart:669` still renders the placeholder. That is
  correct: the catalog's job is to show what the class is, and the class is a placeholder.

## Verification

No code changed, so the baseline is untouched by construction.
`flutter analyze lib/features/settings/` → **No issues found!** (8.5s). `flutter test` unchanged:
4664 pass / 61 skip / 1 pre-existing fail (`gesture_log_test`, local-SDK skew, green in CI).
No new `.dart` files, so no `git add -N` was required.
