# l10n queue — M3-18 onboarding-funding (`/jeeber/onboarding/funding`)

Two keys. Everything else the restyle needed already exists in **both** catalogs
(verified against `lib/l10n/app_en.arb` / `app_ar.arb` on 2026-08-04).

## Why anything is queued at all

The restyle carries R4's money lockup onto the starter-credit hero: an eyebrow
over the figure, and a labelled stat in the reserve row's trailing slot. Both of
those slots are *labels the pass-1 screen never had*, because pass-1 drew a bare
number in each. The numbers were always unlabelled; naming them is what the
money family requires (R4 labels every figure it draws).

## 1. `fundingStarterCreditLabel`

Currently on the nearest existing key, `fundingTitle` ("Your starter credit"),
tagged `TODO(midnight): l10n-queued` at
`lib/features/jeeber_onboarding_funding/presentation/onboarding_funding_screen.dart`
(the `_StarterCreditHero(label:)` argument).

`fundingTitle` is *correct* today — it names exactly the thing the figure is —
but it is also the top-bar title, so the capture reads "Your starter credit"
twice, 60dp apart. R4's own lockup does not do this: the bar says "Wallet" and
the eyebrow says "Available to bid". An eyebrow is a short noun phrase in the
`sectionLabel` ramp (11/w700/+1.2, uppercased by `JeebSectionLabel`), not a
sentence with a possessive.

```
file: lib/l10n/app_en.arb
  "fundingStarterCreditLabel": "Starter credit",
  "@fundingStarterCreditLabel": {"description": "M3-18 eyebrow above the starter-credit figure on onboarding-funding (JeebSectionLabel uppercases it). Do NOT reuse fundingTitle: that is the top-bar title on the same screen and repeating it reads as a duplicate heading."},

file: lib/l10n/app_ar.arb
  "fundingStarterCreditLabel": "الرصيد الابتدائي",

file: lib/l10n/app_localizations.dart
  String get fundingStarterCreditLabel => _get('fundingStarterCreditLabel');
```

After it lands: swap the `label:` argument and drop the TODO. No test re-points
— `onboarding_funding_screen_test.dart` asserts identifiers and styles, never
this string.

## 2. `fundingReservedNowLabel`

Currently on the nearest existing key, `walletHubReservedNow` ("Reserved now"),
tagged `TODO(midnight): l10n-queued` at the same file (`_ReservedNowStat`).

The string is right and the meaning is identical — it is the same D1 figure the
wallet's bank-card footer labels — so reading it is safe. It is queued only
because it is *wallet-hub-scoped* copy (`@walletHubReservedNow` says "R4 wallet
bank-card footer label"), and a second screen silently depending on it means a
wallet-side rewording would move copy on the KYC funnel without anyone looking.

```
file: lib/l10n/app_en.arb
  "fundingReservedNowLabel": "Reserved now",
  "@fundingReservedNowLabel": {"description": "M3-18 label above the live reserve figure in the reserve-rule row on onboarding-funding (D1). Same string as walletHubReservedNow by design; scoped so a wallet-side rewording cannot silently move KYC-funnel copy."},

file: lib/l10n/app_ar.arb
  "fundingReservedNowLabel": "محجوز حالياً",

file: lib/l10n/app_localizations.dart
  String get fundingReservedNowLabel => _get('fundingReservedNowLabel');
```

## Deliberately NOT queued

- **The wallet-read error block's copy.** `walletHubTitle` ("Wallet"),
  `walletHubLoadError` ("We couldn't load your wallet. Please try again.") and
  `walletHubRetry` ("Retry") are read **as-is**, not as stand-ins. The call that
  failed *is* `WalletRepository.fetchBalance()` — the same call R4 makes — so
  wallet-scoped failure copy is the accurate noun, and R4's own state block
  already pairs exactly these three. A scoped duplicate would add three keys
  with identical strings and a worse noun.
- **An empty-rung headline.** The zero-amount state ships as the copy-only
  explainer with no empty block: a headline saying "no starter credit yet" would
  contradict `fundingStarterCreditBody`, which already explains that the credit
  arrives on approval. Nothing is faked and nothing is queued.
- **`fundingTopupCta` / `fundingContinueCta` / `fundingReserveBody` /
  `fundingStarterCreditBody`.** Unchanged, in both catalogs, and pinned by the
  flow — this was a re-skin, not a product change.
