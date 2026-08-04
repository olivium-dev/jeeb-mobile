# l10n queue — M4 · kyc / location / deep_link_targets state lane

Verified against `lib/l10n/app_en.arb` + `app_ar.arb` on 2026-08-04.

**No copy was invented.** Every string this lane renders is already shipped in
both ARBs. Three call sites carry `TODO(midnight): l10n-queued` because the key
they use was written for a *different* surface, or because one key is doing the
work of two. Four more sites became *less* indebted: two hard-coded English
strings and one hard-coded English fallback were replaced with shipped keys.

---

## 1. REQUIRED — three queued keys

| Key | EN | AR | Call site |
|---|---|---|---|
| `kycSchemaLoadingHeadline` | `Getting your form ready` | `جارٍ تجهيز النموذج` | `kyc_wizard_screen.dart` · `_SchemaLoadingView` |
| `kycStatusLoadingHeadline` | `Checking your verification` | `جارٍ التحقق من توثيقك` | `kyc_status_view.dart` · `isLoadingStatus` |
| `kycSchemaErrorHeadline` + `kycSchemaErrorBody` | `Couldn't load the form` / `Check your connection and try again.` | *(split of the existing AR string)* | `kyc_wizard_screen.dart` · `_SchemaErrorView` |

### 1.1 `kycSchemaLoadingHeadline`

The wizard's `schema` step had **no string at all** — it was a bare spinner, so
§2.7's headline slot has nothing shipped to fill it.

**Stand-in in use:** `accountStatusLoadingHeadline` — *"Checking your account"*.
It is the nearest true statement: the wizard is preparing this account's
verification. **Rejected:** `kycWizardTitle` (*"Become a Jeeber"*) — the top bar
already renders it verbatim one row above, and the header-band rule bans the
repeat; `addressFormLoadingHeadline` (*"Opening the address form"*) — right verb,
wrong noun.

### 1.2 `kycStatusLoadingHeadline`

Same shape: the `isLoadingStatus` branch was `Center(child: OmdsLoadingState())`
with no copy.

**Stand-in in use:** `offerKycGateStatusChecking` — *"Checking your verification
status…"*. This is **exactly** what the surface does; the only debt is that the
key is named for the offer-KYC gate, so a reader greps the wrong screen. Copy is
correct today, so this is the lowest-risk of the three.

### 1.3 The `kycErrorSchemaLoadFailed` split

`kycErrorSchemaLoadFailed` is *"Couldn't load the form. Check your connection and
try again."* — **two sentences in one key**, because it was written for a
snackbar. §2.7 wants a short `h1` headline plus a muted body.

**What ships now:** the whole key, verbatim, as the headline, with no body. That
is zero copy change and nothing false, but it wraps to three lines of `h1` (see
`captures/M4/kyc/kyc__wizard__schema-error-radar.png`). **Rejected:** splitting
it in Dart (a `split('. ')` on localized copy breaks in Arabic), and borrowing
`deliveryStatusErrorTitle` (*"Connection lost"*) as the headline — it asserts a
cause the code does not know.

The key is still used by the wizard's error **snackbar** (`_messageFor`), so it
cannot simply be re-worded in place; the split needs two new keys.

---

## 2. DEBT PAID — no key needed, already shipped

| Was | Now | File |
|---|---|---|
| `'KYC Status coming soon'` (hard-coded EN) | `kycStatusTitle` | `deep_link_targets/kyc_status_screen.dart` |
| `'This screen is not yet available.'` (hard-coded EN) | `kycStatusPlaceholder` | same |
| `emptyLabel ?? 'No matches'` (hard-coded EN fallback) | `locationSearchEmpty` | `location/presentation/location_search_bar.dart` |

`kycStatusPlaceholder` — *"Your verification status will appear here."* — is
worth calling out: it keeps the deep-link target **honestly unbuilt** (see Q7 in
the M4 inventory) while removing the English-only slab. Restyling it did not
make it claim to be finished.

---

## 3. Deliberately NOT queued

- **The submitting step.** `kycSubmittingTitle` / `kycSubmittingBody` were
  already the right two strings and moved onto the kit's `headline` / `body`
  slots unchanged.
- **`GpsDeniedState`.** All three of `captureLocationGpsDeniedTitle` / `Body` /
  `OpenSettings` are shipped and correct; only the widget around them changed.
- **The create-flow cold read.** `savedAddressesLoadingHeadline` — *"Loading your
  addresses"* — is literally what both frames are waiting on, and both are frames
  of the same cold start, so ONE string across the two is right, not a defect.
- **The four inline waits** (capture tile, mutation overlay, GPS row, search
  progress). No copy: a row-trailing mark that announces itself in text would be
  a second live region on a surface that already has one.
