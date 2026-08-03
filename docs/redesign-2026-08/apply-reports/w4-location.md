# w4-location — apply report

**Lane:** `location` (the two screens the design board never drew)
**Files owned:**
- `lib/features/location/presentation/saved_locations_screen.dart`
- `lib/features/location/presentation/screens/address_detail_form_screen.dart`

**Reference:** no render exists for either screen. The language was taken from the neighbour,
`docs/redesign-2026-08/screens/09-location-picker.{png,html}`, plus the already-redesigned
in-directory siblings (`client_location_screen.dart`, `client_location_add_row.dart`,
`saved_address_pill_row.dart`, `current_location_status_card.dart`) and screen 20
(`settings_more_card.dart`) as the house convention for grouped rows.

**Not touched (per the brief):** both `location_picker_screen.dart` files (dead), and every
screen-09 file — those are already on the system.

---

## What the neighbour does that these two did not

| Screen 09 (redesigned) | These two, before |
| --- | --- |
| In-body `JeebTopBar` header — no elevation, no surface tint, no centred title | `OMDSAppBar` (Material `AppBar`, centred title) |
| Docked navy pill footer, `JeebCtaFooter.single`, pad `24/0/24/32` | `FloatingActionButton.extended` (saved-list) / `OmdsLoadingButton` in a 16px `SafeArea.minimum` (form) |
| 24px side gutters everywhere (`DeliveryCreateLayout.pagePadding`) | 16px list gutter + an 8px tile inset |
| Each option = a white `JeebOutlinedCard`, r16, 1.5px brown outline, no shadow; cards separated by whitespace | Flat rows separated by a 1px `Divider` |
| Type from `context.jeebText` (`cardTitle` / `bodySmall`), navy = the fact, brown = its qualifier | `textTheme.bodyLarge` / `bodySmall` / `titleSmall` / `titleMedium` |
| Filled category glyphs (`Icons.home` / `work` / `place`) at 20px navy | `_outlined` variants at the default 24px |

---

## Changes — `saved_locations_screen.dart`

1. **Header** — `OMDSAppBar` → in-body `JeebTopBar.back(title:, identifier: 'saved_addresses_back')`
   inside `SafeArea(bottom: false) → Column`. The kit default `onLeadingPressed` is
   `Navigator.maybePop()`, byte-equivalent to what `OMDSAppBar._buildBackButton` did — no
   behaviour change. `RootAwareBackScope` still wraps the whole `Scaffold`.
2. **Add CTA** — `FloatingActionButton.extended` → `JeebCtaFooter.single` +
   `JeebCtaButton.primary(leadingIcon: Icons.add)` docked at the bottom. No FAB is drawn anywhere
   on the 24-screen board. Same affordance, same action, same enablement rule, and the
   `saved_address_add_cta` Semantics wrapper is byte-identical (kept *without* `ExcludeSemantics`
   so the node still carries a live tap action, exactly as it did over the FAB).
3. **List rhythm** — 24px gutters; `Divider(height: 1)` separator → `SizedBox(height: Spacing.small)`
   (R7/R12: two outlined cards already draw their own separation).
4. **Row** — the bespoke `InkWell` + `Padding` → `JeebOutlinedCard(onTap:)`.
   **Deliberately not `JeebListRow`:** its `title` is a plain `String`, and this row must keep the
   default badge *inline with the label* while the edit/overflow controls stay fixed-width — the
   original "no overflow when the badge + two affordances coexist" constraint. Folding three things
   into the kit row's single `trailing` slot is exactly the crowding that constraint forbids.
   Padding trimmed to `16/4/8/4` for the same reason `ClientLocationAddRow` trims its own: the
   trailing `IconButton`s already carry 48dp boxes.
   Side-effect (an improvement): the card's `Semantics(container: true, explicitChildNodes: true)`
   now *guarantees* the nested `saved_address_<n>_edit` / `_more` / `_default_badge` identifiers
   survive, instead of relying on the hand-added `onTap` workaround documented on `_EditButton`.
5. **Tokens** — title `context.jeebText.cardTitle` navy, subtitle `context.jeebText.bodySmall`
   `onSurfaceVariant`; category glyphs switched to the filled set at `Sizes.large` (R10), matching
   the sibling `SavedAddressPillRow` byte-for-byte.
6. **Default badge** — `OmdsChip(primaryContainer)` → `JeebSystemChip.filled(center: false)`.
   "Default" is a settled fact, not a do-it-now moment, so it takes the quiet
   `surfaceContainerHigh` chip — **not** the rationed orange badge (§4.1 keeps solid accent for
   `Recommended` / `Best value`).
7. **Action sheet** — sheet radius 20 → 24 (`OmdsBorderRadius.topXLarge`, §4.4); 24px gutter;
   header `titleMedium` → `jeebText.titleProminent` navy; the free-standing `Divider()` and the two
   `OmdsSettingsRow`s → one `JeebOutlinedCard.grouped` of two `JeebListRow`s (`showChevron: false` —
   these act in place). Destructive ink via `iconColor` + a merged `titleStyle`. Both
   `saved_address_sheet_*_cta` wrappers unchanged.

**Left alone on purpose:** `_EmptyView` / `_ErrorView` (`OmdsEmptyState` / `OmdsErrorState`) — they
are the fleet's honest zero/error surfaces, already token-clean, and pinned by
`test/saved_locations_screen_test.dart`. The loading spinner and the mutation overlay are unchanged.

## Changes — `address_detail_form_screen.dart`

1. **Header** — `OMDSAppBar` → in-body `JeebTopBar.back(identifier: 'address_form_back')`.
   `Semantics(identifier: 'address_detail_form_root')` still wraps the `Scaffold` unchanged.
2. **Gutters** — form `ListView` 16 → 24 start/end (§4.3 `--screen-gutter`).
3. **Pin section** — `Text(titleSmall)` → `JeebSectionLabel` (uppercase, w700, ls 1.2, periwinkle,
   locale-gated casing). Preview band border `outlineVariant` @1px → `colorScheme.outline` @1.5px,
   the board's card stroke.
4. **Edit pin** — `OMDSOutlinedButton` → `JeebCtaButton.outline(expand: false)` (intrinsic width; it
   is a secondary action parked at the band's end, not a docked pill). `find.text('Edit pin')` still
   resolves — the pin-picker test is green.
5. **Save bar** — `SafeArea.minimum(16/12/16/16)` + `OmdsLoadingButton` → `SafeArea(top: false)` +
   `JeebCtaFooter.single` + `JeebCtaButton.primary(isLoading:, isEnabled:)`. `isLoading` is a
   first-class kit param, so the `DecoratedBox`/`JeebShadows.ctaNavy` dance `client_location`
   needed around `OmdsLoadingButton` is unnecessary here.
6. Text fields untouched — `OmdsTextField` is the fleet input and there is no kit input widget; the
   09 lane kept it too.

---

## Refusals / non-changes

- **No new strings.** `AddressFormL10n` (the feature-local EN/AR helper) and `_defaultBadgeLabel`
  are pre-existing and untouched. No ARB edit, no `gen-l10n`.
- **No shared-file edits** → no `wiring/w4-location.md` request was needed.
- **No flow change.** Same steps, same order, same affordances, same navigation, same copy.
- **Latent defect left in place (behaviour, not skin):** when this manager is reached by
  `goNamed('settings-addresses')` (from `customer-profile`, and from the form's own save) it is the
  stack root, so the *visible* back control is a no-op — only the system-back gesture is rescued, by
  `RootAwareBackScope`. Screen 20 solves this with
  `onLeadingPressed: () => context.canPop() ? context.pop() : context.go(...)`. I did **not** adopt
  it here: it is a navigation change, and the brief says re-skin only. Flagged for the owner.
- **No orange added.** Neither screen has a decaying/do-it-now moment; the only accent-eligible
  element would be the delete action, and destructive stays `colorScheme.error`.

## Gates

| Gate | Result |
| --- | --- |
| `dart analyze lib/features/location/` | **No issues found** |
| `flutter test test/features/location/ test/saved_locations_screen_test.dart` | **42 passed, 0 failed** |
| `flutter test test/core/router/back_nav_system_back_test.dart test/core/router/w1_routes_resolve_test.dart` | **passed** |
| banned-pattern grep (raw hex, `Colors.*`, literal `SizedBox`/`EdgeInsets`/`BorderRadius.circular`/`fontSize`, raw `AppBar`/`TextField`/…) over both files | **0 hits** |

Every pre-existing `Semantics(identifier:)` is byte-identical:
`saved_address_add_cta`, `saved_address_default_badge`, `saved_address_<n>_edit`,
`saved_address_<n>_more`, `saved_address_sheet_edit_cta`, `saved_address_sheet_delete_cta`,
`address_detail_form_root`, `address_form_map_pin`, `address_form_edit_pin_cta`,
`address_form_label`, `address_form_building`, `address_form_floor_apt`,
`address_form_delivery_notes`, `address_form_cod_phone`, `address_form_save_cta`.
Two new ids, both `<screen>_back`: `saved_addresses_back`, `address_form_back`.
