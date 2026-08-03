# W4 — `jeeber-funding` (JM-041 onboarding-funding) — apply report

**Screen:** `lib/features/jeeber_onboarding_funding/presentation/onboarding_funding_screen.dart`
**Board render:** none — this screen was never drawn. Language taken from its journey neighbour
**23-wallet** (`screens/23-wallet.png` + the shipped `wallet_hub_screen.dart`), which the jeeber
reaches from this screen's own top-up CTA.
**Status:** done. `dart analyze lib/features/jeeber_onboarding_funding
test/features/jeeber_onboarding_funding` → *No issues found*. Screen tests 5/5 green; the router
test that mounts this screen (`test/core/router/w2_routes_resolve_test.dart`) 7/7 green.

---

## 1. What the screen looked like before

`OMDSAppBar` + a 16px-gutter `ListView` of two **`OMDSSectionCard`s that both carried the same
title** (`l10n.fundingTitle`, "Your starter credit" — the reserve card's heading was a copy/paste),
each with `theme.textTheme.bodyLarge/bodyMedium` body copy and an ad-hoc
`headlineSmall.copyWith(fontWeight: w700)` amount, then two stacked `OmdsPrimaryButton`s
(`secondary` + `primary`) sitting immediately under the last card. No navy anywhere, no accent
anywhere, no ramp styles, no empty lower third — it read as a generic M3 form next to the wallet it
links to.

## 2. What it looks like now

Three bands over a real empty third, mirroring 23:

| Band | Kit widget | Notes |
|---|---|---|
| Header | `JeebTopBar` (`identifier: 'funding_back'`) | in-body 40px circle + `h2` title; back logic (`canPop ? pop : go('/')`) carried over verbatim |
| Starter credit (D42) | `JeebNavySurfaceCard` r20, `JeebShadows.heroNavy`, `rings: [JeebNavyRing.statBottomEnd]` | the *same* preset the wallet balance hero wears, so the jeeber's two money surfaces are visibly one family. Amount in `jeebText.statHero` on `onPrimary` (FittedBox `scaleDown` for 200% text), explainer copy in `jeebText.body` on `onPrimary` |
| Reserve rule (D1) | `JeebInfoNote.accent` + `Icons.lock` + trailing amount | trailing value styled `cardTitle` w800 navy — byte-for-byte the treatment of 23's `wallet_reserved_now` value |
| Footer | `JeebCtaFooter.single` (`child:` outline top-up, `below:` primary Continue) | docked at the foot of the viewport via `SliverFillRemaining(hasScrollBody: false)` + `Align(bottomCenter)` — the neighbour's exact idiom |

Measured geometry at 440×956 (probe test, since a golden could not be produced — see §6):

```
topbar  T0    B58
hero    L24 R416  T74  B275     ← 24px gutters, 16 under the bar
note    L24 R416  T287 B437     ← 12px block gap
· · ·   371px of plain white (39% of the viewport) — R1's real emptiness
topup   L24 R416  T808 B858     ← outline pill h50
cont.   L24 R416  T868 B924     ← primary navy pill h56, 32px bottom inset
```

Money now goes through `MoneyFormat.format` (the app-wide formatter, LTR-isolated) instead of the
file-local `_formatMoney`, which printed `5.00 USD` while every other jeeber money surface prints
`$5.00`. `_formatMoney` deleted.

## 3. What did NOT change (deliberately)

- **Flow:** same route, same two CTAs, same order (top-up first, Continue second), same targets
  (`wallet-charge-info` / `kyc-status?step=status`), same fail-safe load behaviour.
- **Copy:** all five existing ARB keys used unchanged. No new strings invented, no string
  hardcoded, no feature-local `_pick` map added.
- **Identifiers:** `funding_explainer`, `funding_topup_cta`, `funding_continue_cta`,
  `funding_starter_credit_amount`, `funding_reserved_now_amount` are byte-identical, including the
  `container: true` / `button: true` wrappers around both CTAs (Maestro `jm-041-onboarding-funding`
  taps them by id, and `jm-040-kyc-identity` waits on `funding_explainer`). `funding_explainer`
  still scopes the explainer body only — the top bar sits outside it, exactly as the app bar did.
  One NEW id: `funding_back` (kit `<screen>_back` contract).
- **No in-app payment implied** (D92/D93): nothing on the screen suggests a card. Top-up is still
  only a link to the store-charge explainer, and it is now the *secondary* (outline) affordance.

## 4. Screen-specific refusals / judgement calls

- **No `JeebSectionLabel` eyebrow in the hero.** 23 always labels its hero ("AVAILABLE TO BID").
  The only string that fits here is `fundingTitle`, which is already the top-bar title — using it
  twice would read as a bug. Fidelity here needs one new key (§5); I refused to hardcode it.
- **The reserve note uses tone `accent`, not `outlined`.** `outlined` is 23's reserved-now
  treatment, but its strip-form body ink is periwinkle, and this note's body is a full two-sentence
  rule, not a four-word sub — periwinkle body copy on white is banned by the DS. `accent` is the
  tone whose ink is navy (its orange is only the optional link, which this note does not have), so
  the copy stays readable with zero custom ink and no escape hatch.
- **No orange affordance.** Orange appears exactly once, as the 30% decorative ring on the hero.
  There is no honest fee-explainer or link target on this screen to spend an `accentText` CTA on,
  and the plan rations orange to "what is happening right now" — nothing here is.

## 5. Deferred (not blocking; needs the integrator's ARB batch)

Two optional keys would close the remaining gap to 23. **The shipped code does not reference them**
— nothing is broken without them:

| Proposed key | EN | Why |
|---|---|---|
| `fundingStarterCreditLabel` | `Starter credit` | hero eyebrow (`JeebSectionLabel`), so the navy number is labelled the way 23's is |
| `fundingReserveTitle` | `Reserved right now` | would let the reserve note take 23's stacked `outlined` form (navy title + muted sub + trailing value) instead of the flat `accent` strip |

## 6. Verification

- `dart analyze lib/features/jeeber_onboarding_funding test/features/jeeber_onboarding_funding` →
  **No issues found**.
- `flutter test test/features/jeeber_onboarding_funding/onboarding_funding_screen_test.dart` →
  **5/5**. New file (the screen had zero widget coverage): pins the four frozen ids + `funding_back`,
  the enrichment gating on non-zero amounts, the fail-safe path (repository throws → explainer and
  both CTAs still render), and an `ar` RTL smoke that would fail on any overflow.
- `flutter test test/core/router/w2_routes_resolve_test.dart` → **7/7**.
- **A rendered screenshot could not be produced on this machine**: every `flutter test` run that
  calls `test/support/load_test_fonts.dart` dies with `Shell subprocess crashed with SIGTERM`
  (reproduced 4×; the same test without the font loader runs fine, so it is the environment — ~20
  lanes are on this box — not the screen). The visual claims above are therefore backed by measured
  widget rects and by code-level parity with `wallet_hub_screen.dart`, not by eyeballing a PNG.
