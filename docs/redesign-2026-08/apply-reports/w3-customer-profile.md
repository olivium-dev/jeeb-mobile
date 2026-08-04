# w3 — customer-profile onto the Jeeb design system

**No render exists for this screen** (it is one of the 46 the 24-screen board never drew). The
reference was therefore the *language* of its neighbour, `screens/20-settings.png` / `.html`, and
the two in-repo screens that already realize it (`settings_screen.dart` + its widgets,
`wallet_hub_screen.dart`).

Target: `lib/features/customer_profile/` — a TOP-LEVEL shell tab, so it sat next to four redesigned
tabs looking like a different product.

---

## What the neighbour does, and what this screen did instead

| | `20-settings` (redesigned) | `customer-profile` (before) |
| --- | --- | --- |
| Identity | navy card r18, Ø50 avatar, white name, periwinkle subtitle, `JeebShadows.ctaNavy` — the one shadowed surface | bare `Padding` on white: Ø80 `OmdsProfileAvatar` + `headlineSmall` navy name |
| Growth edge | orange-framed `JeebAccentFrameCard`, Ø38 accent disc, accent `Start` word | a plain row with a navy `OmdsPrimaryButton` "Register" pill as trailing |
| Section headers | `JeebSectionLabel` — UPPERCASE, periwinkle, 12.5/w700, ls 1.2 | navy `titleMedium` w700, sentence case |
| Rows | `JeebOutlinedCard.grouped` + `JeebListRow`: r16 outline, inset dividers, filled navy glyph, muted chevron | free-floating full-bleed rows, Ø32 **navy filled disc** behind each glyph, `labelLarge` on `onSurfaceVariant` |
| Sign out | own outlined card, 18px mirrored exit glyph, **no chevron** | last row of the Support list, chevron, `Icons.logout_outlined` |
| Gutters | 24 side, blocks at 12/16 with 8 under each label | 24 baked into every band separately |

---

## What changed

**`presentation/customer_profile_screen.dart`** — the list now owns the 24px gutter once
(`EdgeInsetsDirectional.fromSTEB(24, 56, 24, 32)`); the 56 top inset that used to live inside the
header is preserved verbatim, because it is what keeps the identity card out from under the
shell-overlaid `customer_profile_wallet_chip` / `_bell`. One 12px gap between the identity card and
the rows. **No behaviour, navigation, cubit, repository or callback touched.**

**`widgets/customer_profile_header.dart`** — rebuilt as the navy identity card:
`JeebNavySurfaceCard(radius: 18, shadow: JeebShadows.ctaNavy)` holding `JeebAvatar(diameter: 50)`
(which re-tones itself to the board's `rgba(255,255,255,.14)` disc via `JeebSurfaceTone`, no
parameter), name in `jeebText.cardTitle` on `onPrimary`, rating + email in periwinkle
`JeebSemanticColors.mutedText`. `Sizes.eightXLarge` avatar, `theme.textTheme.headlineSmall`,
`colorScheme.secondaryContainer` and `onSurfaceVariant` are all gone.

**`widgets/customer_profile_rating.dart`** — restyled only. The star now takes
`JeebSurfaceTone.of(context).titleInk` (white on navy, navy on a light surface) instead of
`colorScheme.primary`, which would have been invisible on the new card; the label moved to
`jeebText.bodySmall` + `mutedText`. Deliberately **not** `omdsColorTokens.starRatingColor` — §4.1
rations warm ink, and `JeebProfileHeader`'s test-pinned navy star is the same rule.

**`widgets/customer_profile_register_card.dart`** (new) — replaces `customer_register_pill.dart`.
`JeebAccentFrameCard` + Ø38 `jeebRoles.accent` disc + accent `Register` word: the screen's entire
orange budget, spent exactly where the neighbour spends it. The old pill was already
`ExcludeSemantics`'d onto the row's single node with the same `onTap`, so folding it into the card
loses no target; `Key('customer-profile-register-button')` moved onto the accent label.

**`widgets/customer_profile_rows.dart`** — `JeebSectionLabel` + two `JeebOutlinedCard.grouped`
cards of `JeebListRow`s, plus a third one-row card for sign out (`showChevron: false`, 18px glyph,
`JeebOutlinedCard.defaultPadding` — the same three arguments `settings_footer.dart` passes). Glyphs
swapped to their FILLED twins per R10 (`lock_outline`→`lock`, `notifications_none`→`notifications`,
`language_outlined`→`language`, `location_on_outlined`→`location_on`, `call_outlined`→`call`,
`star_outline`→`star`).

**Deleted** (dead after the swap, referenced nowhere else in `lib/` or `test/`):
`customer_profile_row.dart`, `customer_profile_icon_disc.dart`,
`customer_profile_section_header.dart`, `customer_register_pill.dart`.

## What deliberately did NOT change

- Every `Semantics(identifier:)` is byte-identical: `customer_profile_root`, `_avatar`, `_name`,
  `_rating`, `_register_delivery_row`, `_password_row`, `_notifications_row`, `_language_row`,
  `_addresses_row`, `_contact_row`, `_rate_app_row`, `_logout_row`. `CustomerProfileScreen.rootKey`
  and `Key('customer-profile-avatar')` survive too.
- Action order, destinations, the `showRegister` gate, the `AppReviewLauncher` seam, the
  `LogoutDeleteConfirmSheet` call, the cubit/repository wiring: untouched.
- **No new copy.** Every string is an existing ARB key; no ARB or `app_localizations.dart` edit.
  The board's "Earn on errands you're already making" subtitle under the growth card was *not*
  borrowed — that would be a product copy change, not a re-skin.
- **No new affordance.** The neighbour's identity card is tappable (→ edit profile) and shows a
  chevron; this tab has no edit-profile edge, so the card is inert and chevron-less rather than
  growing a navigation edge the restyle was not asked for.

## Gates

- `dart analyze lib/features/customer_profile` → **No issues found**
- `flutter test test/customer_profile_screen_test.dart` → **9/9 pass** (incl. the exact-identifier
  contract, the `find.text('Register')` assertion and the AR mirroring test)
- `flutter test test/decision_violations_test.dart test/semantics_identifier_surfacing_test.dart`
  → **17/17 pass**
- `dart analyze lib/features/shell lib/devtool/catalog/entries/batch_02_entries.dart` (the two
  external consumers) → **No issues found**
- `tool/check_design_tokens.sh` → 3 violations, all pre-existing and in other lanes' files
  (`client_location_screen.dart`, `wallet_activity_list_screen.dart`, `reviews_list_screen.dart`);
  zero in `customer_profile`.
- Zero `Color(0x`, zero raw `TextStyle(`, zero `fontSize:` in the feature.

## Wiring requests filed (both non-blocking)

`docs/redesign-2026-08/wiring/w3-customer-profile.md` — a shared `DirectionalIcons.signOut` (the
mirrored-logout codepoint is now declared privately in two files), and tone-awareness or a `color`
param on `JeebVerifiedBadge` (it hardcodes navy `secondaryContainer`, invisible on the navy card;
worked around here with a scoped `Theme` override).

## Remaining inconsistencies vs the neighbour

See `selfCritique` in the lane output; summarised: no screen-title band, no docked-to-foot sign-out,
no subtitle on the growth card, no chevron on the identity card, kit row padding 14/16 vs the
board's 13/16, and the periwinkle-on-navy meta lines carry real data at ~2.5:1 contrast (the same
treatment the shipped Settings identity subtitle uses).
