# Wiring requests — 22 · Become a Jeeber (KYC wizard)

One request. No route, DI, theme, kit, or cross-feature change is needed — the shipped Wave-1 kit
already covers everything this screen consumes (`JeebMeter.segmented` was built from this
screen's HTML; `JeebCtaButton.disabledFillOpacity = 0.45` and `JeebOutlinedCard(radius:,
padding:)` already exist).

### l10n
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb + lib/l10n/app_localizations.dart
need: 4 value changes and 10 new keys for the redesigned KYC identity step; getters follow the
house `_get` + `replaceFirst` pattern (no ICU plural engine in this repo).
exact change:

app_en.arb — **value changes** (keys exist; no test or Maestro flow pins the old English values —
verified by grep 2026-08-03):
```json
  "kycWizardTitle": "Become a Jeeber",
  "kycIdFrontLabel": "ID — front",
  "kycIdBackLabel": "ID — back",
  "kycSelfieStepTitle": "Selfie",
```

app_en.arb — **new keys**:
```json
  "kycWizardProgressStepLabel": "Step {current} of {total} — {stepName}",
  "@kycWizardProgressStepLabel": { "description": "KYC wizard progress header, left side. Supersedes kycWizardProgressLabel by folding in the step name.", "placeholders": { "current": { "type": "int", "example": "1" }, "total": { "type": "int", "example": "2" }, "stepName": { "type": "String", "example": "Your ID" } } },
  "kycWizardNextStepHint": "then {stepName}",
  "@kycWizardNextStepHint": { "description": "KYC wizard progress header, right side — what comes after the current step. Hidden on the last step.", "placeholders": { "stepName": { "type": "String", "example": "Selfie" } } },
  "kycWizardStepIdTitle": "Your ID",
  "@kycWizardStepIdTitle": { "description": "Step-1 name in the KYC progress header (kycWizardStepIdLabel 'ID' stays for other consumers)." },
  "kycIdCaptureHint": "Lay it flat, avoid glare",
  "@kycIdCaptureHint": { "description": "Sub-line of a pending gov-ID capture row. Replaces the deleted KycIdAlignmentGuide coaching." },
  "kycCaptureCaptured": "Captured",
  "@kycCaptureCaptured": { "description": "Sub-line of a captured KYC row, rendered with a check icon in the success role colour. Deliberately NOT 'looks sharp' — the app has no capture-quality signal." },
  "kycSelfieLockedHint": "Step 2 — unlocks after your ID",
  "@kycSelfieLockedHint": { "description": "Sub-line of the locked selfie row (UI-only lock; the cubit path stays open for tests/Maestro)." },
  "kycReviewTimeTitle": "Review usually takes under 24 hours",
  "@kycReviewTimeTitle": { "description": "Title line of the kyc_review_note info note on the identity step." },
  "kycReviewPrivacyNote": "Your documents are never shown to customers.",
  "@kycReviewPrivacyNote": { "description": "Body of kyc_review_note. The board's 'encrypted and' clause is HELD pending owner/legal ratification (C4) — do not add it here without that sign-off." },
  "kycTosAgreeLine": "I agree to the Jeeber terms — deliver what's asked, collect cash honestly, {percent}% fee per won offer.",
  "@kycTosAgreeLine": { "description": "ToS checkbox title. {percent} is ALWAYS kJeebCommissionPercent — never hardcode 10 (jeeb_commission_test.dart guards the Dart side; this key is the ARB side of the same rule).", "placeholders": { "percent": { "type": "int", "example": "10" } } },
  "kycTosReadFullCta": "Read the full terms",
  "@kycTosReadFullCta": { "description": "Text CTA (kyc_tos_read_cta) opening the ToS document sheet (kyc_tos_document_sheet)." },
```

app_ar.arb — value changes + new keys (proposed AR; l10n owner may refine wording, not structure):
```json
  "kycWizardTitle": "كن جيبر",
  "kycIdFrontLabel": "الهوية — الوجه الأمامي",
  "kycIdBackLabel": "الهوية — الوجه الخلفي",
  "kycSelfieStepTitle": "صورة شخصية",
  "kycWizardProgressStepLabel": "الخطوة {current} من {total} — {stepName}",
  "kycWizardNextStepHint": "ثم {stepName}",
  "kycWizardStepIdTitle": "هويتك",
  "kycIdCaptureHint": "ضعها مسطّحة وتجنّب الانعكاسات",
  "kycCaptureCaptured": "تم التقاطها",
  "kycSelfieLockedHint": "الخطوة ٢ — تُفتح بعد إتمام هويتك",
  "kycReviewTimeTitle": "تستغرق المراجعة عادةً أقل من ٢٤ ساعة",
  "kycReviewPrivacyNote": "لا تُعرض مستنداتك على العملاء أبدًا.",
  "kycTosAgreeLine": "أوافق على شروط جيبر — التوصيل كما هو مطلوب، وتحصيل النقد بأمانة، ورسوم {percent}٪ عن كل عرض تفوز به.",
  "kycTosReadFullCta": "اقرأ الشروط كاملة",
```

app_localizations.dart (house pattern — matches `kycWizardProgressLabel` at :761-764):
```dart
  String kycWizardProgressStepLabel({
    required int current,
    required int total,
    required String stepName,
  }) =>
      _get('kycWizardProgressStepLabel')
          .replaceFirst('{current}', '$current')
          .replaceFirst('{total}', '$total')
          .replaceFirst('{stepName}', stepName);
  String kycWizardNextStepHint({required String stepName}) =>
      _get('kycWizardNextStepHint').replaceFirst('{stepName}', stepName);
  String get kycWizardStepIdTitle => _get('kycWizardStepIdTitle');
  String get kycIdCaptureHint => _get('kycIdCaptureHint');
  String get kycCaptureCaptured => _get('kycCaptureCaptured');
  String get kycSelfieLockedHint => _get('kycSelfieLockedHint');
  String get kycReviewTimeTitle => _get('kycReviewTimeTitle');
  String get kycReviewPrivacyNote => _get('kycReviewPrivacyNote');
  String kycTosAgreeLine({required int percent}) =>
      _get('kycTosAgreeLine').replaceFirst('{percent}', '$percent');
  String get kycTosReadFullCta => _get('kycTosReadFullCta');
```

Orphaned by this change (warn-level; integrator may retire in BOTH locales, not the lane):
`kycWizardProgressLabel`, `kycIdStepTitle`, `kycIdStepSubtitle`, `kycSelfieStepSubtitle`,
`kycIdAlignmentGuideTitle`, `kycIdAlignmentGuideCaption`, `kycTosSignAndSubmit`.
(`kycTosStepSubtitle` was already unconsumed before this change.)
KEEP: `kycTosDocumentBody`, `kycTosStepTitle`, `kycIdRetake`, `kycIdCaptureCta`,
`kycSelfieRetake`, `kycSelfieCaptureCta`, `kycScrollForSelfieHint`, `kycWizardStepIdLabel`,
`kycWizardStepSelfieLabel`.

None of the new key names resemble the D20-banned set
(`decision_violations_test.dart:162-168`): `kycWizardStepVehicleLabel`, `kycVehicleStepTitle`,
`kycVehicleRegistrationLabel`, `kycStatusResubmitCta`.

why: the redesigned identity step's progress header ("Step 1 of 2 — Your ID" / "then Selfie"),
per-row capture hints and captured state, the UI-locked selfie row, the review-time/privacy info
note, the plain-words terms line (fee via `{percent}` = `kJeebCommissionPercent`), and the
read-full-terms CTA are all user-visible strings; the screen title becomes the flow's real name.
