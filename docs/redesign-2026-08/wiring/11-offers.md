# Wiring requests — screen 11 · Offers (`11-offers`)

Everything below is outside `lib/features/client_offers/` and therefore not this lane's to edit.
The screen code is already written **as if these are granted**; until the integrator lands the l10n
block, `lib/features/client_offers/` does not compile (4 undefined `AppLocalizations` members).

The four kit requests in the revised instruction set (§6 `jeeb_select_chip` / `jeeb_top_bar` /
`jeeb_meter` / `jeeb_info_note`) are **already satisfied by the shipped Wave-1 kit** — verified
2026-08-03 against `lib/core/widgets/jeeb/`: `JeebChipRole.sort` has no min-height,
`JeebTopBar.subtitle` + `identifier` exist, `JeebMeter.value` is nullable, and
`JeebInfoNoteTone.error` + `trailing` both exist. No kit change is requested.

---

### l10n
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb + lib/l10n/app_localizations.dart
need: three new strings and one six-branch plural family for the offers screen redesign.
exact change:
app_en.arb —
```json
  "offersSortByBest": "Best",
  "@offersSortByBest": { "description": "Third offer-review sort chip (offer_review_sort_best): composite best-value ranking (fee asc, rating desc, ETA asc)." },
  "offersCardBestValueBadge": "Best value",
  "@offersCardBestValueBadge": { "description": "Solid-orange badge on the top-ranked offer card (offer_card_<n>_best_value_badge). Suppressed for single-offer lists." },
  "offersCardFastestBadge": "Fastest",
  "@offersCardFastestBadge": { "description": "Muted pill after the Jeeber name on the unique-lowest-ETA card (offer_card_<n>_fastest_badge)." },
  "offersWindowStripZero": "No offers yet · window closes in {time}",
  "offersWindowStripOne": "1 offer in · window closes in {time}",
  "offersWindowStripTwo": "2 offers in · window closes in {time}",
  "offersWindowStripFew": "{count} offers in · window closes in {time}",
  "offersWindowStripMany": "{count} offers in · window closes in {time}",
  "offersWindowStripOther": "{count} offers in · window closes in {time}",
  "@offersWindowStripOther": { "description": "Offer-review countdown strip (offer_review_window_strip): live offer count + server-deadline countdown. Six Arabic CLDR plural branches; English reuses one/other. {time} is CountdownFormat output.", "placeholders": { "count": { "type": "int", "example": "3" }, "time": { "type": "String", "example": "4:12" } } },
```
app_ar.arb —
```json
  "offersSortByBest": "الأفضل",
  "offersCardBestValueBadge": "أفضل قيمة",
  "offersCardFastestBadge": "الأسرع",
  "offersWindowStripZero": "لا عروض بعد · تُغلق المهلة خلال {time}",
  "offersWindowStripOne": "وصل عرض واحد · تُغلق المهلة خلال {time}",
  "offersWindowStripTwo": "وصل عرضان · تُغلق المهلة خلال {time}",
  "offersWindowStripFew": "وصلت {count} عروض · تُغلق المهلة خلال {time}",
  "offersWindowStripMany": "وصل {count} عرضًا · تُغلق المهلة خلال {time}",
  "offersWindowStripOther": "وصل {count} عرض · تُغلق المهلة خلال {time}",
```
app_localizations.dart (house pattern, matches `pendingCardOffersBadge` at :1852) —
```dart
  String get offersSortByBest => _get('offersSortByBest');
  String get offersCardBestValueBadge => _get('offersCardBestValueBadge');
  String get offersCardFastestBadge => _get('offersCardFastestBadge');
  String offersWindowStrip(int count, String time) {
    String branch;
    if (count == 0) {
      branch = _get('offersWindowStripZero');
    } else if (count == 1) {
      branch = _get('offersWindowStripOne');
    } else if (count == 2) {
      branch = _get('offersWindowStripTwo');
    } else {
      final mod = count % 100;
      branch = mod >= 3 && mod <= 10
          ? _get('offersWindowStripFew')
          : mod >= 11 && mod <= 99
              ? _get('offersWindowStripMany')
              : _get('offersWindowStripOther');
    }
    return branch
        .replaceFirst('{count}', '$count')
        .replaceFirst('{time}', time);
  }
```
why: the redesigned sort bar's third chip, the two ranking badges, and the merged
count-plus-countdown strip are all user-visible strings; the strip is plural-sensitive in Arabic
and must pass `qa/t-mob-fix-002/ar_plurals_check.sh`.

---

## Keys this lane STOPPED calling (integrator's call whether to retire)

`offersPanelHeader` · `offersSortLabel` · `offersWindowRemaining`. All three are still present in
both ARBs; nothing else in `lib/` reads them after this change. This lane deliberately does not
delete them (§5 of the instruction set).
