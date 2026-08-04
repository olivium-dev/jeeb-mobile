# Wiring requests — screen 23 · Wallet (`23-wallet`)

**One request, and it is NON-BLOCKING.** The lane ships every redesigned string through
`lib/features/wallet/presentation/wallet_hub_l10n.dart`'s `_pick` EN/AR maps (the JM-031 / JM-045
precedent), so `lib/features/wallet/` compiles, analyzes and tests green today. This request folds
those strings into the ARB layer afterwards with **no call-site change**.

All six kit wiring requests from the original Opus proposal (`JeebInfoNote` tones + `trailing`,
`JeebNavySurfaceCard` bottom-END ring, `JeebCtaButton` leading glyph / `accentText`,
`JeebOutlinedCard.grouped` dividers, `JeebTopBar` back identifier, `JeebListRow` mirrored chevron)
were re-verified against the shipped Wave-1 kit on 2026-08-03 and are **already satisfied
in-tree**. They are withdrawn — no kit change is requested, and no kit file was touched.

---

### l10n
file: lib/l10n/app_en.arb, lib/l10n/app_ar.arb, lib/l10n/app_localizations.dart
need: fold the wallet-hub redesign copy out of `wallet_hub_l10n.dart`'s `_pick` maps into real keys; one existing value change; one NEW key so the shared top-up label is not touched.
exact change:
app_en.arb — change in place (single consumer, `wallet_hub_l10n.dart`):
```json
"walletAvailableBalanceLabel": "Available to bid",
```
app_en.arb — add (append-only; `walletTopUpCta` stays untouched — it is shared with kyc_status_view.dart:515,737 and offer_composer_l10n.dart:163):
```json
"walletTopUpWalletCta": "Top up wallet",
"@walletTopUpWalletCta": { "description": "JM-053 wallet-hub primary CTA (wallet_topup_cta); distinct from the shared short walletTopUpCta." },
"walletBackLabel": "Back",
"@walletBackLabel": { "description": "A11y label for the wallet-hub top-bar back circle (wallet_back)." },
"walletGiftBadge": "{amount} starter credit",
"@walletGiftBadge": { "description": "Starter-credit pill on the balance hero (wallet_gift_badge, D42). {amount} arrives pre-formatted by MoneyFormat. Deliberately NOT the word included — the contract does not define gift/balance composition.", "placeholders": {"amount": {}} },
"walletAffordabilityEnoughTitle": "You're set to bid",
"walletAffordabilityEnoughBody": "Enough balance for the {rate}% reserve on typical offers.",
"@walletAffordabilityEnoughBody": { "description": "{rate} MUST be interpolated from kJeebCommissionPercent (single-rate rule).", "placeholders": {"rate": {}} },
"walletReservedRightNowLabel": "Reserved right now",
"walletReservedRightNowHint": "Released if you're not picked.",
"walletHowFeesWorkCta": "How fees work — the {rate}%, explained",
"@walletHowFeesWorkCta": { "placeholders": {"rate": {}} },
"walletEarningsRowTitle": "Earnings",
"walletEarningsRowSubtitle": "Cash collected, fees paid",
"walletAllActivityTitle": "All activity",
"walletAllActivitySubtitle": "Top-ups, reserves, releases",
"walletCashDisclaimer": "Customer cash never passes through this wallet.",
"walletFeesExplainerLine1": "You only pay a flat {rate}% platform fee on offers you win.",
"@walletFeesExplainerLine1": { "description": "D41/D44: platform fee, never Commission; {rate} from kJeebCommissionPercent.", "placeholders": {"rate": {}} }
```
app_ar.arb — same keys:
```json
"walletAvailableBalanceLabel": "متاح للمزايدة",
"walletTopUpWalletCta": "اشحن المحفظة",
"walletBackLabel": "رجوع",
"walletGiftBadge": "رصيد بداية {amount}",
"walletAffordabilityEnoughTitle": "أنت جاهز للمزايدة",
"walletAffordabilityEnoughBody": "رصيدك يكفي لحجز الـ{rate}٪ على العروض المعتادة.",
"walletReservedRightNowLabel": "محجوز الآن",
"walletReservedRightNowHint": "يُعاد إليك إذا لم يقع الاختيار عليك.",
"walletHowFeesWorkCta": "كيف تعمل الرسوم — شرح الـ{rate}٪",
"walletEarningsRowTitle": "الأرباح",
"walletEarningsRowSubtitle": "النقد المُحصَّل والرسوم المدفوعة",
"walletAllActivityTitle": "كل النشاط",
"walletAllActivitySubtitle": "الشحن والحجوزات والإفراجات",
"walletCashDisclaimer": "نقود العميل لا تمر أبداً عبر هذه المحفظة.",
"walletFeesExplainerLine1": "تدفع رسوم منصة ثابتة {rate}٪ فقط على العروض التي تفوز بها."
```
app_localizations.dart — plain getters for the un-parameterized keys; the placeholder keys follow the hand-rolled `replaceFirst` pattern (`app_localizations.dart`, e.g. `chatBroadcastTtlLabel`):
```dart
String walletGiftBadge(String amount) =>
    _get('walletGiftBadge').replaceFirst('{amount}', amount);
String walletAffordabilityEnoughBody(int rate) =>
    _get('walletAffordabilityEnoughBody').replaceFirst('{rate}', '$rate');
String walletHowFeesWorkCta(int rate) =>
    _get('walletHowFeesWorkCta').replaceFirst('{rate}', '$rate');
String walletFeesExplainerLine1(int rate) =>
    _get('walletFeesExplainerLine1').replaceFirst('{rate}', '$rate');
```
why: the redesigned wallet hub renders this copy today from `wallet_hub_l10n.dart`'s lane-local `_pick` maps (the JM-031/JM-045 precedent); folding it into the ARB layer retires that resolver's temporary strings with no screen change. The `{rate}` placeholders keep `kJeebCommissionPercent` as the only copy of the rate.

---

**Open question for the owner (not a file change — record the answer here when it comes):**
is `WalletBalance.giftCredit` *included in* or *additive to* `availableBalance`? The board's pill
says "included"; the contract (`lib/features/wallet/domain/wallet_repository.dart`,
`DioWalletRepository._parse`) does not define it. Until answered, the pill ships the neutral
`{amount} starter credit` and the word "included" is deliberately absent.

**Second open item (data, not wiring):** the board's reserve row reads
`1 live offer · released if you're not picked`. `WalletBalance` carries the reserved *amount* only —
no live-offer count exists on the wire. The count half is omitted (marked `TODO(redesign-24)` in
`wallet_hub_screen.dart`), never faked.
