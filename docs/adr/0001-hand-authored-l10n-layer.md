# ADR 0001 — Hand-authored localization layer instead of `gen_l10n`

- Status: Accepted
- Date: 2026-06-12
- Deciders: Jeeb mobile engineering

## Context

Jeeb mobile ships EN + AR with full RTL. Flutter's first-party path is
`flutter gen_l10n`, which generates a typed `AppLocalizations` class from ARB
files at build time. This repo instead uses a **hand-authored**
`lib/l10n/app_localizations.dart`: a `LocalizationsDelegate` that loads the
ARB JSON into a `Map<String, String>` and exposes one getter per key via a
private `_get('<key>')` lookup.

This choice predates the UI-parity work and was undocumented, which a PR review
(TL-7) flagged. This ADR records the decision and its consequences so the
deviation from the framework default is intentional and auditable.

## Decision

Keep the hand-authored localization layer. Drivers:

1. **Deterministic test parity gates.** `test/l10n/runtime_parity_test.dart`
   and the `qa/t-mob-fix-002` scripts assert EN/AR key-set equality and that no
   rendered value equals its key. The map-backed layer exposes
   `byKey`/`allStrings` test seams (`@visibleForTesting`) that make these gates
   trivial; `gen_l10n` output is harder to introspect this way.
2. **No codegen step in CI.** The map loader needs no `flutter gen_l10n`
   invocation or generated-file freshness check, removing a CI failure mode
   (stale generated `app_localizations.dart` drifting from the ARB).
3. **Plural/RTL control.** AR CLDR plural dispatch and `AutoDirectionText`
   wiring are hand-tuned against the ARB; the explicit layer keeps that logic in
   one readable place.

## Consequences

- (−) No compile-time safety on key names: a typo in a getter surfaces at
  runtime via the `_get` assert, not at compile time. Mitigated by the parity
  tests, which run in CI.
- (−) Adding a key is a three-step edit (EN ARB + AR ARB + a getter). Mitigated
  by the parity test failing loudly on any missing side.
- (+) Zero codegen; faster, simpler CI.
- (+) Strong, machine-checked EN/AR parity and no-stub guarantees.
- **Orphan getters:** the l10n report shows getters that exceed live call
  sites. These are warn-only and are **not** pruned in this PR to avoid churn
  unrelated to the UI-parity scope; pruning is tracked as follow-up debt.

## Alternatives considered

1. **Migrate to `flutter gen_l10n`.** Gains compile-time key safety but loses
   the test seams above, adds a codegen + freshness-check step to CI, and would
   be a large, scope-expanding migration mid-parity-work. Deferred; revisit if
   key-name typos become a recurring defect source.
2. **Third-party (`slang`, `easy_localization`).** Adds a dependency and a
   different codegen/runtime model for no clear gain over the current approach;
   rejected.
