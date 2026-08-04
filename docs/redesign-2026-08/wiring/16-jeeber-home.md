# Wiring requests — 16 · Jeeber home

Companion to `per-screen-revised/16-jeeber-home.md` (the authoritative spec). Lane code is
written as if W-1 is granted; Task 8 of the lane is gated on W-2.

---

### l10n
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb + lib/l10n/app_localizations.dart
need: nine new keys for the redesigned header, chip counts, search toggle, inline Extend, and the rebuilt feed/active cards (W-2/W-3 consumers included so this is ONE batch).
exact change (EN, with @-metadata; integrator applies the 4-edit recipe per key):
```json
"jeeberDashboardEyebrow": "Jeeber dashboard",
"@jeeberDashboardEyebrow": {"description": "Eyebrow line above the jeeber-home greeting name"},
"jeeberFeedNearbyCount": "Nearby {count}",
"@jeeberFeedNearbyCount": {"placeholders": {"count": {}}},
"jeeberFeedPendingCount": "Pending {count}",
"@jeeberFeedPendingCount": {"placeholders": {"count": {}}},
"jeeberFeedRepliesCount": "Replies {count}",
"@jeeberFeedRepliesCount": {"placeholders": {"count": {}}},
"jeeberFeedSearchToggleLabel": "Search requests",
"@jeeberFeedSearchToggleLabel": {"description": "Semantics label for the collapsed-search magnifier button"},
"availabilityExtendAction": "Extend",
"@availabilityExtendAction": {"description": "Inline CTA word in the availability strip that resets the idle timer"},
"availabilityInactivityInlineWarning": "Going offline soon",
"@availabilityInactivityInlineWarning": {"description": "One-line inline form of the inactivity warning; the old availabilityInactivityWarningBody says 'Tap below' which is wrong for the inline CTA"},
"jeeberFeedMakeOfferAction": "Make offer",
"@jeeberFeedMakeOfferAction": {"description": "Board wording for the feed-card offer CTA (today's jeeberFeedOfferAction = 'Offer' stays for any other caller)"},
"jeeberActiveLabel": "Active",
"@jeeberActiveLabel": {"description": "Prefix token of the pinned active-delivery card title, e.g. 'Active: Medicine → Rue Monot'"}
```
exact change (AR):
```json
"jeeberDashboardEyebrow": "لوحة الجيبر",
"jeeberFeedNearbyCount": "بالجوار {count}",
"jeeberFeedPendingCount": "قيد الانتظار {count}",
"jeeberFeedRepliesCount": "الردود {count}",
"jeeberFeedSearchToggleLabel": "ابحث في الطلبات",
"availabilityExtendAction": "تمديد",
"availabilityInactivityInlineWarning": "ستصبح غير متصل قريبًا",
"jeeberFeedMakeOfferAction": "قدّم عرضًا",
"jeeberActiveLabel": "نشط"
```
Also needed by W-2's relative timestamp ("2 min ago"): three plural keys following the
`notifications_l10n.dart:130–143` precedent —
```json
"jeeberFeedMinutesAgo": "{count, plural, =0{Just now} one{1 min ago} other{{count} min ago}}",
"@jeeberFeedMinutesAgo": {"placeholders": {"count": {}}},
"jeeberFeedHoursAgo": "{count, plural, one{1 h ago} other{{count} h ago}}",
"@jeeberFeedHoursAgo": {"placeholders": {"count": {}}},
"jeeberFeedDaysAgo": "{count, plural, one{1 d ago} other{{count} d ago}}",
"@jeeberFeedDaysAgo": {"placeholders": {"count": {}}}
```
```json
"jeeberFeedMinutesAgo": "{count, plural, =0{الآن} one{قبل دقيقة} two{قبل دقيقتين} few{قبل {count} دقائق} many{قبل {count} دقيقة} other{قبل {count} دقيقة}}",
"jeeberFeedHoursAgo": "{count, plural, one{قبل ساعة} two{قبل ساعتين} few{قبل {count} ساعات} many{قبل {count} ساعة} other{قبل {count} ساعة}}",
"jeeberFeedDaysAgo": "{count, plural, one{قبل يوم} two{قبل يومين} few{قبل {count} أيام} many{قبل {count} يومًا} other{قبل {count} يوم}}"
```
Reused, no new keys: `availabilityStatusOnline/Offline/AutoOffline`, `availabilityTransitioning`,
`availabilityAutoOfflineHint`, `availabilityIndicatorSemantic*`, `homeGreetingNamed/Fallback`,
`requestFeedEmptyTitle/Subtitle`, `jeeberFeedEmptyTitle/Subtitle`,
`jeeberActiveDeliveriesManage`, `activeDeliveryStatus*`, `jeeberFeedIgnoreAction`,
`jeeberFeedTier*`.
why: the profile header eyebrow, count chips, search toggle semantics, the inline Extend affordance, and the W-2/W-3 card copy are all user-visible strings and must pass the AR/EN parity gate.

---

### cross-feature
file: lib/features/jeeber_request_feed/presentation/jeeber_feed_card.dart (+ rewrite of test/jeeber_feed_card_test.dart)
need: rebuild `JeeberFeedCard` to the board's two-row content model; this screen is its only production consumer (verified: sole importer is `jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart`), but the file is outside lane 16's ownership.
exact change: apply §1.7/§2/§4.5/C-16.6 of `per-screen/16-jeeber-home.md` as amended by `per-screen-revised/16-jeeber-home.md`. Binding contract:
- Constructor gains `this.isFreshest = false` and `this.isVoice = false` (both `bool`). No other signature change; `exposeMakeOfferId` and all callbacks stay.
- Shape: `JeebOutlinedCard` (kit #3, r16, 1.5px `colorScheme.outline`, NO shadow), outer padding `EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge, vertical: Spacing.twoXSmall)`.
- Row 1 (gap Spacing.xSmall): `if (isVoice) JeebWaveform.cardMark()` · `Expanded(Text(request.itemsSummary ?? <existing fallback chain>, jeebText.cardTitle, primary, maxLines 1, ellipsis))` · relative time from `receivedAt` via the new `jeeberFeedMinutesAgo/HoursAgo/DaysAgo` keys (`jeebText.caption`, mutedText). Keep the SW-03 `.toLocal()` conversion.
- Row 2 (margin-top Spacing.small, gap Spacing.xSmall): `JeebTierChip(tier)` (kit #7, one treatment for all tiers — kills the per-tier tint and this file's `.tertiary` fallbacks) · `Flexible(Text('{distanceFromYouKm formatted} · {pickup.label}', jeebText.bodySmall, mutedText, 1 line))` rendering whichever half exists (both fields verified present on `DeliveryRequest`; keep `NumberFormat.decimalPattern(locale)` + wrap the numeric run in an LTR isolate) · `Spacer()` · action area.
- Actions: KEEP Ignore (`jeeber_feed_request_ignore_<id>` frozen; `JeebCtaButton.text` in `onSurfaceVariant` — R4 secondary-word rank, no longer error-red) before the offer pill. Offer pill = `JeebCtaButton` `accent` variant (+`0 6 14 rgba(215,59,0,.35)` glow) when `isFreshest`, else `outline` (navy ink); label `l10n.jeeberFeedMakeOfferAction`. Pending/accepted/expired branches keep their exact identifiers, Keys, `IntrinsicWidth` end-alignment, and the linger-window `opacityDisabled` fade.
- DELETE `_ClientAvatar`, `_ClientName`, `_RatingCluster` (the identity moves off the card; it lives on request detail). Do NOT delete `feed_make_offer_cta` wrapping logic.
- Every identifier in the file survives byte-identical: `jeeber_feed_request_card_<id>`, `_ignore_`, `_offer_`, `_expired_`, `_action_`, `feed_make_offer_cta`; `explicitChildNodes: true` stays on the card root.
- Test rewrite: drop the identity-led assertions (`Sami Fawaz`, avatar/client-name Keys, `OmdsStarRatingDisplay`, the avatar/content geometry proof, the 2-line summary contract, `3km away from you`); KEEP the expiry group, the `IntrinsicWidth` hugging proofs, the RTL test (`TextDirection.rtl` + `فلاش`), and retarget the SW-03 device-local test at the new relative-time formatter. Note `jeeber_feed_card_test` is already red on main in CI — do not count its pre-existing failure.
why: the board's feed card leads with what the job is (title + tier + distance + one decaying CTA); screen 16 renders these cards and its lane cannot edit this feature directory.

---

### cross-feature
file: lib/features/jeeber_active_deliveries/presentation/active_deliveries_banner.dart (+ update of test/features/shell/jeeber_active_card_push_render_test.dart)
need: rebuild the active-delivery surface as the board's one-row accent-framed card; screen 16 is its only rendering surface (injected by `dashboard_tab.dart`), but both files are outside lane 16's ownership.
exact change: apply §1.5/§2 of `per-screen/16-jeeber-home.md` as amended by the revised doc. Binding contract:
- ONE delivery → always expanded (the designer note pins the just-won delivery; the new card is ~64dp so it cannot bury the feed). TWO OR MORE → keep today's disclosure row, whose expanded rows use the new compact card. `jeeber_active_deliveries_view_all` therefore emits only at ≥2 — accepted, verified no Maestro flow references it.
- Compact card: `JeebAccentFrameCard` (kit #5, 2px `jeebRoles.accent`, r16, no shadow, pad 13/16-equivalent tokens), Row gap 12: Ø38 `jeebRoles.accent` disc + white `Icons.two_wheeler` (`jeebRoles.onAccent`) · Expanded Column: `'{l10n.jeeberActiveLabel}: {title}'` + directional arrow + dropoff when present (NEVER a hardcoded `→` — two TextSpans with a localized/directional connector), `jeebText.body` w700 primary, 1 line ellipsis; subtitle `{statusLabel}` via the existing `activeDeliveryStatus*` getters, `jeebText.bodySmall` mutedText — NO cash amount (`ActiveDeliverySummary` has no amount field; add `// TODO(redesign-24): needs a cash-due field on GET /v1/deliveries?role=jeeber — omitted, not faked.`) · navy `Manage` pill (`l10n.jeeberActiveDeliveriesManage`) → `onManageDelivery`.
- Card tap keeps opening chat (`onOpenChat`); DELETE `_ActiveDeliveryCardActions`, `_ButtonLabel`, `_StatusChip` (status folds into the subtitle), and the `OMDSGlassCard`.
- Identifiers survive byte-identical: `jeeber_active_deliveries`, `jeeber_active_deliveries_view_all` (≥2 only), `jeeber_active_delivery_row_<id>`, `jeeber_active_delivery_open_chat_<id>`, `jeeber_active_delivery_manage_<id>`; `container: true` + `explicitChildNodes: true` stay on the root.
- Test update (`jeeber_active_card_push_render_test.dart:192–195`): `find.text('View all (1)')` → the expanded card's row identifier; keep the push-reaction assertions (refetch count, banner within two frames, feed row not displaced) untouched.
why: the board pins the just-won delivery as a one-row orange-framed card with a single Manage pill; the current two stacked ~180dp icon buttons are the largest visual delta above the fold on this screen.

---

### cross-feature
file: .maestro/flows/24-delivery-screen-delivery-man.yaml + .maestro/flows/25-iphone-16-17-pro-max-9-dm-request-pending.yaml
need: both flows assert/tap `jeeber_feed_search_field` at rest; after the C8 search collapse the field only mounts once the magnifier is tapped, so each flow needs one added step. No identifier is renamed.
exact change: in BOTH files, immediately BEFORE the first step that references `id: "jeeber_feed_search_field"` (24: line ~51; 25: line ~50), insert:
```yaml
- tapOn:
    id: "jeeber_feed_search_toggle"
- waitForAnimationToEnd:
    timeout: 3000
```
why: keeps the two E2E flows honest against the collapsed-by-default search sanctioned by 02-PLAN-ENHANCED C8, without weakening any assertion.

---

### cross-feature
file: lib/core/widgets/jeeb/ (Wave-1 kit lane — contract corrections, no lane-16 code depends on guesses)
need: four kit-contract facts measured from `screens/16-jeeber-home.html` that differ from or extend the plan §5 table.
exact change:
1. `JeebWaveform.cardMark` on 16 is **3 bars, w2.5, h 7/12/9, gap 2, container h14, all bars full `jeebRoles.accent`** (tpl 933–936) — not the 4-bar `.4`-tail profile the plan specs for 04. Either `cardMark` takes a bars/heights profile or 16's mark is off-spec; decide once in Wave 1.
2. `JeebProfileHeader` must expose an `avatarIdentifier` (or avatar-slot) parameter applied via an explicit `Semantics(identifier: …)` wrapper — 16 passes the frozen `jeeber_home_avatar`, and the avatar must render unconditionally (initial disc when `avatarUrl == null`).
3. `JeebSelectChip(role: filter)`: 16 renders counts INLINE in the label ("Nearby 12", tpl 924–925) — the orange count-badge slot is not used on this screen; the label-only form must exist.
4. `JeebNavySurfaceCard`: 16's availability strip shadow is `0 10 24 rgba(11,19,81,.28)` = `JeebShadows.ctaNavy` exactly (tpl 907). Plan §5 #4 / 02-PLAN-ENHANCED R6c group 16 with 21's `0 8 20 .25` — wrong for 16; the HTML wins.
why: prevents a Wave-1 default from silently forking 16's strip, mark, chips, or breaking the frozen avatar identifier.
