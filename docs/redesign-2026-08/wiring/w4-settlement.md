# Wiring requests — w4 · Settlement

Lane: `lib/features/settlement/**`. One request, **non-blocking** — the lane compiles, analyzes
clean and its tests pass without it. No route, DI, theme, l10n or kit change is needed.

### test gate — extend the color-role guard to the extracted pill

file: `test/core/theme/no_raw_semantic_colors_test.dart`

why: the guard pins two settlement paths (`settlement_screen.dart`, `settlement_detail_screen.dart`)
because those files coloured paid/pending state with `jeebRoles.success*/warning*`. The re-skin
de-duplicates that mapping — both screens hand-rolled the same chip — into
`lib/features/settlement/presentation/widgets/settlement_status_pill.dart`. The two listed paths are
still correct and still pass, but the semantic-role usage they were guarding now lives one file
lower, outside the list. Adding the new path restores the coverage the sweep intended.

exact change (one line, inside `migratedFiles`, under the "Journey 3" comment):

```dart
    'lib/features/settlement/presentation/settlement_screen.dart',
    'lib/features/settlement/presentation/settlement_detail_screen.dart',
    'lib/features/settlement/presentation/widgets/settlement_status_pill.dart',
```

verified: the new file passes all four forbidden patterns today (no `Color(0x…)`, no `.tertiary*`,
no `Colors.<palette>`, no container-role-as-ink), so the added case is green on arrival.
