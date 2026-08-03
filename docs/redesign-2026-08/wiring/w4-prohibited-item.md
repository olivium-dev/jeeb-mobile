# Wiring requests — w4 · prohibited-item report

> Written at implementation time, 2026-08-03, by the `prohibited-item` W4 lane.
> Screen: `lib/features/prohibited_item_report/presentation/prohibited_item_report_screen.dart`
> (an ORPHAN — JEBV4-227; zero routes, reachable only from the dev-tool catalog).
>
> **Kit requests: NONE.** `JeebTopBar.back`, `JeebInfoNote.warning`, `JeebCtaButton.outline`,
> `JeebCtaButton.primary` and `JeebCtaFooter.single` are consumed exactly as shipped. Nothing in
> `lib/core/widgets/jeeb/` was read as insufficient.
>
> **Route requests: NONE.** The screen deliberately stays unrouted; the live report path is
> `ProhibitedItemReportService` in `jeeber_request_detail`. This lane re-skinned it, it did not
> resurrect it.
>
> **One OPEN request: `l10n`.**
>
> Implementation note: the five keys are served today by a feature-local stopgap resolver,
> `lib/features/prohibited_item_report/presentation/prohibited_item_report_l10n.dart` — the
> `OtpHandoverL10n` (13) / `LiveTrackingL10n` (12) precedent. All five strings were **hardcoded
> English literals before this pass**; the stopgap keeps the EN wording byte-identical and adds the
> AR side, so the screen is RTL-complete in copy as well as layout with 0 analyze errors today.
> When the integrator lands the block below, each stopgap getter becomes a one-line delegation to
> `AppLocalizations` and the file is deleted.
>
> The lane's widget tests (`test/features/prohibited_item_report/`) assert through the getters, not
> through literals, so the swap is a no-op for every gate. No `Semantics(identifier:)` depends on
> any of this copy.

---

### l10n

file: `lib/l10n/app_en.arb` + `lib/l10n/app_ar.arb` + `lib/l10n/app_localizations.dart`

need: five NEW keys for the prohibited-item report screen. None of them exist today — the closest
neighbours (`jeeberRequestDetailReport*`) belong to the LIVE report path and carry different
wording, so reusing them would silently change this screen's copy. This repo's `AppLocalizations`
is a hand-authored runtime ARB parser (no gen-l10n, no ICU), so the getters are hand-added too.

exact change:

`app_en.arb` — append (all NEW):
```json
  "prohibitedItemReportTitle": "Report Prohibited Item",
  "@prohibitedItemReportTitle": {
    "description": "Top-bar title of the prohibited-item report screen"
  },
  "prohibitedItemReportGuidance": "If the Client requested delivery of a prohibited item, report it here.",
  "@prohibitedItemReportGuidance": {
    "description": "Caution note above the form explaining when to use the screen"
  },
  "prohibitedItemReportDescriptionLabel": "Describe the prohibited item",
  "@prohibitedItemReportDescriptionLabel": {
    "description": "Floating label of the free-text description field"
  },
  "prohibitedItemReportAttachPhotoCta": "Attach Photo",
  "@prohibitedItemReportAttachPhotoCta": {
    "description": "Secondary outline action — attach optional photo evidence"
  },
  "prohibitedItemReportSubmitCta": "Report Item",
  "@prohibitedItemReportSubmitCta": {
    "description": "Docked primary action that submits the prohibited-item report"
  },
```

`app_ar.arb` — append (values verbatim from the stopgap; lexicon matches the live report path's
`jeeberRequestDetailReport*`: صنف ممنوع / إبلاغ):
```json
  "prohibitedItemReportTitle": "الإبلاغ عن صنف ممنوع",
  "prohibitedItemReportGuidance": "إذا طلب العميل توصيل صنف ممنوع، أبلغ عنه هنا.",
  "prohibitedItemReportDescriptionLabel": "صف الصنف الممنوع",
  "prohibitedItemReportAttachPhotoCta": "إرفاق صورة",
  "prohibitedItemReportSubmitCta": "إبلاغ عن الصنف",
```

`app_localizations.dart` — append the five getters (no plurals, no placeholders):
```dart
  String get prohibitedItemReportTitle => _get('prohibitedItemReportTitle');
  String get prohibitedItemReportGuidance =>
      _get('prohibitedItemReportGuidance');
  String get prohibitedItemReportDescriptionLabel =>
      _get('prohibitedItemReportDescriptionLabel');
  String get prohibitedItemReportAttachPhotoCta =>
      _get('prohibitedItemReportAttachPhotoCta');
  String get prohibitedItemReportSubmitCta =>
      _get('prohibitedItemReportSubmitCta');
```

follow-up for this lane once landed: delete
`lib/features/prohibited_item_report/presentation/prohibited_item_report_l10n.dart`, replace
`ProhibitedItemReportL10n.of(context)` with `AppLocalizations.of(context)` in
`prohibited_item_report_screen.dart` (five call sites, same getter names minus the
`prohibitedItemReport` prefix mapping below), and repoint the two test-file constants.

| stopgap getter | shared key |
|---|---|
| `copy.title` | `prohibitedItemReportTitle` |
| `copy.guidanceNote` | `prohibitedItemReportGuidance` |
| `copy.descriptionLabel` | `prohibitedItemReportDescriptionLabel` |
| `copy.attachPhotoCta` | `prohibitedItemReportAttachPhotoCta` |
| `copy.reportCta` | `prohibitedItemReportSubmitCta` |
