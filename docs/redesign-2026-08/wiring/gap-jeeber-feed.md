# Wiring requests — gap lane `jeeber_request_feed` (screen 16, feed cards + active banner)

Companion to `apply-reports/gap-jeeber-feed.md`. Everything below is a SHARED-file change the lane
could not make itself. The lane code compiles and is green **without** any of it — each request has
a named, already-in-place fallback, so applying these is a copy-in, never a rescue.

---

### l10n
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb + lib/l10n/app_localizations.dart
need: four keys from the original W-1 batch (`wiring/16-jeeber-home.md`) that were NOT applied when
the rest of that batch landed. Nine of the thirteen are live; these four are missing.
exact change (EN, with @-metadata; integrator applies the 4-edit recipe per key):
```json
"jeeberFeedMakeOfferAction": "Make offer",
"@jeeberFeedMakeOfferAction": {"description": "Board wording for the feed-card offer CTA (today's jeeberFeedOfferAction = 'Offer' stays for any other caller)."},
"jeeberFeedMinutesAgo": "{count, plural, =0{Just now} one{1 min ago} other{{count} min ago}}",
"@jeeberFeedMinutesAgo": {"placeholders": {"count": {"type": "int"}}},
"jeeberFeedHoursAgo": "{count, plural, one{1 h ago} other{{count} h ago}}",
"@jeeberFeedHoursAgo": {"placeholders": {"count": {"type": "int"}}},
"jeeberFeedDaysAgo": "{count, plural, one{1 d ago} other{{count} d ago}}",
"@jeeberFeedDaysAgo": {"placeholders": {"count": {"type": "int"}}}
```
exact change (AR):
```json
"jeeberFeedMakeOfferAction": "قدّم عرضًا",
"jeeberFeedMinutesAgo": "{count, plural, =0{الآن} one{قبل دقيقة} two{قبل دقيقتين} few{قبل {count} دقائق} many{قبل {count} دقيقة} other{قبل {count} دقيقة}}",
"jeeberFeedHoursAgo": "{count, plural, one{قبل ساعة} two{قبل ساعتين} few{قبل {count} ساعات} many{قبل {count} ساعة} other{قبل {count} ساعة}}",
"jeeberFeedDaysAgo": "{count, plural, one{قبل يوم} two{قبل يومين} few{قبل {count} أيام} many{قبل {count} يومًا} other{قبل {count} يوم}}"
```
then, in `lib/features/jeeber_request_feed/presentation/jeeber_feed_card.dart`:
1. `_OfferPill.build` — replace
   `final label = AppLocalizations.of(context).jeeberFeedOfferAction;`
   with `final label = AppLocalizations.of(context).jeeberFeedMakeOfferAction;`
   and delete the `TODO(redesign-24)` above it. (`test/jeeber_feed_card_test.dart` then needs
   `find.text('Offer')` → `find.text('Make offer')` in two places.)
2. `_Timestamp.build` — replace the `DateFormat.Hm(...)` body with the relative age, keeping the
   `.toLocal()` conversion (SW-03) and the `Key('jeeber-feed-card-timestamp')`:
   ```dart
   final age = DateTime.now().difference(receivedAt!.toLocal());
   final text = age.inHours < 1
       ? l10n.jeeberFeedMinutesAgo(age.inMinutes.clamp(0, 59))
       : age.inDays < 1
           ? l10n.jeeberFeedHoursAgo(age.inHours)
           : l10n.jeeberFeedDaysAgo(age.inDays);
   ```
   and retarget the `SW-03 device-local timestamp` group at the new formatter (feed a UTC instant
   two hours old and assert the EN string, not the wall clock).
why: the board reads `Make offer` and `2 min ago`; a feed row's whole job is to look FRESH, and a
wall-clock stamp does not. Rendering today's `jeeberFeedOfferAction` ("Offer") and `DateFormat.Hm`
keeps the tree compiling and every string translated — nothing is faked or hand-rolled outside
`AppLocalizations` — but both are visibly off-board until this lands.

---

### kit
file: lib/core/widgets/jeeb/jeeb_cta_button.dart (FROZEN — do not apply in a screen lane)
need: an accent-filled pill variant, or an accent shadow on the existing one.
exact change: add `JeebCtaVariant.accent` (fill `jeebRoles.accent`, ink `jeebRoles.onAccent`,
shadow `0 6 14 rgba(215,59,0,.35)`), or expose `shadow:`/`fillColor:` overrides on `primary`.
why: the board's freshest feed CTA (tpl 943) and 13's arrival banner are solid orange, and the kit
today has exactly one orange affordance — `accentText`, which is text, not a pill. The lane reaches
the fill by wrapping `JeebCtaButton.primary` in a `Theme` that re-points `colorScheme.primary`/
`onPrimary` at the accent roles (`_OfferPill`, documented in place). That is correct and forks
nothing, but it is a call-site workaround for a missing variant, and the pill still carries the
kit's hardcoded navy `JeebShadows.ctaNavy` under the accent glow the lane paints outside it.

---

### kit
file: lib/core/widgets/jeeb/jeeb_select_chip.dart (FROZEN)
need: the chip's label to be `Flexible` inside its Row.
exact change: wrap the `Text(label, …)` at `:150` in `Flexible(child: …)`.
why: the label is a rigid `Text` in a `mainAxisSize.min` Row, so a chip cannot shrink: under any
bounded width it overflows instead of ellipsizing. That is what forced BOTH pills on this screen
(`_OfferPill`, `_ManagePill`) to be `JeebCtaButton`s rather than the `JeebSelectChip(role:
inlineAction)` the kit table nominates for "a pill that reads as a button inside a card" — with
`Manage delivery` in the chip, the active card overflowed by 129px on a 360dp surface.

---

### cross-feature (ALREADY APPLIED by this lane — recorded so it is not re-litigated)
file: lib/features/jeeber_active_deliveries/presentation/active_deliveries_banner.dart
      + test/features/shell/jeeber_active_card_push_render_test.dart
      + test/features/shell/jeeber_active_deliveries_cap_test.dart
need: W-3 of `wiring/16-jeeber-home.md`, which had never been applied.
exact change: applied verbatim — see `apply-reports/gap-jeeber-feed.md` §2. These four files sit
outside the two directories this lane was told it owns; they were touched because screen 16 is the
banner's only rendering surface and the owner's report named it, and because W-3's own "exact
change" prescribes the `jeeber_active_card_push_render_test` update. Flagged for the integrator in
case a shell lane is editing the same test files concurrently.
why: it is the largest pre-redesign surface left above the fold on this screen.

---

### maestro (NOT applied — no flow currently references these)
file: .maestro/flows/*
need: nothing today. Verified by grep: no flow references `jeeber_active_deliveries_view_all`,
`jeeber_active_delivery_manage_*`, `jeeber_feed_request_ignore_*` or `jeeber_feed_request_offer_*`.
The one behavioural change a flow COULD notice is that a single active delivery no longer hides
behind `View all (1)` — it is on screen immediately, so any flow that tapped the disclosure first
would now find the card already there. None does.
