# Wiring request — w3-escalate (`lib/features/escalate`)

Lane: escalate / `dispute-open-evidence` (JM-060). No board render (one of the 46 undrawn screens);
the language reference is 21 `order-chat`, its entry point.

Nothing in this lane was blocked — the screen shipped without touching a shared file. The two
requests below are **copy defects the redesign surfaced**, both pre-existing, both needing the
hand-authored l10n trio (`app_en.arb` + `app_ar.arb` + `app_localizations.dart`) edited together.

---

## R1 — `escalatePhotoChipLabel` (an English literal is rendered today)

`_PhotoChip` renders `'Photo ${index + 1}'` as a raw Dart string — constraint 4 (all user-visible
strings via `AppLocalizations`). It predates this lane and I left it verbatim rather than invent a
key that would not compile.

Paste-ready:

`lib/l10n/app_en.arb`
```json
  "escalatePhotoChipLabel": "Photo {index}",
  "@escalatePhotoChipLabel": {
    "description": "Label of an attached dispute-evidence photo chip. {index} is 1-based.",
    "placeholders": { "index": { "type": "int" } }
  },
```

`lib/l10n/app_ar.arb`
```json
  "escalatePhotoChipLabel": "صورة {index}",
```

`lib/l10n/app_localizations.dart` — add alongside the other `escalatePhoto*` accessors:
```dart
  String escalatePhotoChipLabel(int index) =>
      _format('escalatePhotoChipLabel', <String, Object>{'index': index});
```
(match the exact `_format`/placeholder helper the neighbouring `escalatePhotoAttached(count)`
accessor uses — it is the same single-placeholder shape.)

Call site to swap afterwards, `escalate_screen.dart` `_PhotoChip.build`:
```dart
label: AppLocalizations.of(context).escalatePhotoChipLabel(index + 1),
```

## R2 — `escalateEvidenceTitle` (one sentence is doing three jobs)

`escalateSubtitle` — *"Describe what went wrong and we'll connect you with our support team within
24 hours."* — was rendered **three times** on this screen before the migration:

1. a bare lede paragraph at the top of the form,
2. immediately beneath it, verbatim, inside `dispute_auto_attach_note`,
3. again as the header of the `dispute_evidence_timeline` card.

(1) and (2) were adjacent duplicates of the same sentence, so this lane collapsed them into the
single `dispute_auto_attach_note` node (same sentence, same position, same identifier). (3) was
left standing — it is ~400px lower and removing it would leave the evidence card untitled.

That still leaves one sentence carrying three different meanings, and none of them well: it is
neither an auto-attach explanation nor an evidence-card title. Two honest keys:

`lib/l10n/app_en.arb`
```json
  "escalateAutoAttachNote": "Your chat and delivery timeline are attached automatically.",
  "@escalateAutoAttachNote": {
    "description": "Dispute form — explains the D53 auto-attached evidence."
  },
  "escalateEvidenceTitle": "Attached automatically",
  "@escalateEvidenceTitle": {
    "description": "Header of the read-only auto-attached evidence card on the dispute form."
  },
```

`lib/l10n/app_ar.arb`
```json
  "escalateAutoAttachNote": "يتم إرفاق محادثتك والخط الزمني للتوصيلة تلقائيًا.",
  "escalateEvidenceTitle": "مُرفق تلقائيًا",
```

`lib/l10n/app_localizations.dart`
```dart
  String get escalateAutoAttachNote => _string('escalateAutoAttachNote');
  String get escalateEvidenceTitle => _string('escalateEvidenceTitle');
```
(use the same plain-getter helper the existing `escalateSubtitle` getter uses.)

Then in `escalate_screen.dart`: `dispute_auto_attach_note` takes `escalateAutoAttachNote`,
`_EvidenceSection`'s header takes `escalateEvidenceTitle`, and `escalateSubtitle` returns to being
the form's single lede paragraph (re-added above the note as `context.jeebText.body`).

**Neither is blocking.** The screen is shipped, green and consistent without them; both are copy
quality, and R2 in particular should be reviewed by whoever owns dispute copy (D53/D76) rather than
pattern-matched from this file.
