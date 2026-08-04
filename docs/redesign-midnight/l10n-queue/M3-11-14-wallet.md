# l10n queue — M3-11..14 · wallet journey (activity list · transaction detail · charge info · customer stub)

New keys the Midnight restyle needs. **Not written to `lib/l10n/*.arb`** (the l10n
lane owns it). Each site currently renders the nearest existing string and carries
`TODO(midnight): l10n-queued`.

The cause is structural, not cosmetic: the three non-loaded states moved from
OMDS panels (which take a *message*) onto `JeebEmptyState` (which takes an `h1`
**headline** plus an optional body). A full sentence ending in a full stop reads
as body copy when it is set in `h1`, and the title of the screen reads as a
tautology when it is the loading headline.

| Key | EN | AR | Site |
|---|---|---|---|
| `walletActivityLoadingHeadline` | `Loading your activity` | `جارٍ تحميل نشاطك` | `wallet_activity_list_screen.dart` loading `_StateBlock` headline — today renders `WalletActivityL10n.title` ("Activity"), which duplicates the top bar verbatim. |
| `walletActivityErrorTitle` | `Couldn't load your activity` | `تعذّر تحميل نشاطك` | `wallet_activity_list_screen.dart` error `_StateBlock` headline — today renders `WalletActivityL10n.loadError`, the same sentence but ending in a full stop, so it reads as a body line in `h1`. |
| `txnDetailLoadingHeadline` | `Loading transaction` | `جارٍ تحميل المعاملة` | `transaction_detail_screen.dart` loading `_StateBlock` headline — today renders `TransactionDetailL10n.title` ("Transaction"), which duplicates the top bar. |
| `txnDetailErrorTitle` | `Couldn't load this transaction` | `تعذّر تحميل هذه المعاملة` | `transaction_detail_screen.dart` error `_StateBlock` headline — today renders `loadErrorGeneric` / `loadErrorNotFound`, both full sentences ("We couldn't load this transaction. Please try again."), which run to three lines in `h1`. The existing strings stay useful as the **body** once a short title exists. |

## Migration note (no code change requested)

`WalletActivityL10n` and `TransactionDetailL10n`
(`lib/features/wallet/presentation/{wallet_activity_l10n,transaction_detail_l10n}.dart`)
carry ~35 strings as inline `_pick(en, ar)` pairs that were never lifted into the
ARB — the whole `typeLabel(type)` / `typeHeading(type)` / `typeBody(type)` ×8
ladders, `loadError`, `networkError`, `retry`, `loadMoreError`, `refLabel`, the
`relativeTime` ladder, and every field label on the detail screen
(`amountLabel` / `dateLabel` / `referenceLabel` / `feeRateLabel` /
`pinnedPriceLabel` / `disputeRefLabel`).

The Midnight restyle promotes four of them to first-class surface copy (two error
headlines, two retry CTA labels), so they are now visually prominent rather than
incidental — same shape as the M3-08 finding. Worth folding into the ARB in the
same pass as the four keys above. M3-11..14 did not touch the file.

## Not queued, deliberately

`wallet_charge_info_screen.dart` (M3-13) and `customer_wallet_stub_screen.dart`
(M3-14) need **no new keys**. Both are static, network-free screens with a single
state and no empty/error copy to write, and every string they draw is already in
the ARB (`chargeInfo*` ×7, `customerWalletStub*` ×6).
