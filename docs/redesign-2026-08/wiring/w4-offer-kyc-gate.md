# Wiring requests — `offer-kyc-gate` lane (w4)

Lane files: `lib/features/offer_kyc_gate/presentation/offer_kyc_gate_screen.dart`,
`lib/features/offer_kyc_gate/presentation/delivery_register_prompt_screen.dart`.

**One request.** No l10n keys, no router change, no DI change, no kit change, no pubspec change.

---

## WR-1 — `test/back_arrow_dead_at_root_test.dart`: the back-affordance finder is `IconButton`-shaped

**Status: BLOCKING. 2 tests are red on this branch until it lands.**

### What changed and why the test trips

Both screens dropped `OMDSAppBar` for the kit's in-body `JeebTopBar.back` (the Ø40
`surfaceContainerHigh` circle + navy `jeebText.h2` title) — the header shape on 17 of the 24 board
screens and the one their neighbour, screen 22 `become-a-jeeber`, wears in the render.

`JeebTopBar` paints its leading circle as `Semantics(button:) > MinTapTarget > DecoratedBox > Icon`.
There is no `IconButton` anywhere in the kit, so this helper now matches nothing on these two
screens:

```dart
Finder _appBarBackButton() => find.widgetWithIcon(IconButton, Icons.arrow_back);
```

**The behaviour the test exists to guard is intact and was re-verified.** The dead-arrow defect
(JEBV4-13 P1-6) was "`maybePop()` no-ops at stack root". Both screens still pass an explicit
`onLeadingPressed` that mirrors their own in-body exit (`canPop ? pop : go('/')`), so tapping the
circle at stack root still lands on `/`. Proven locally with a throwaway probe that drove the exact
same router setup and tapped by identifier: both navigate to `/` and render `HOME`.

### The change requested

Keep `_appBarBackButton()` for the third case (`kyc-rejected` still uses `OMDSAppBar` — it is not in
this lane and was not touched), and add an in-body finder for the two migrated screens:

```dart
Finder _appBarBackButton() => find.widgetWithIcon(IconButton, Icons.arrow_back);

/// Screens migrated to the kit's in-body `JeebTopBar` paint the back
/// affordance as an identified `Semantics(button:) > MinTapTarget` circle,
/// not an `IconButton`. Tap it by its `<screen>_back` identifier.
Finder _inBodyBackCircle(String identifier) =>
    find.bySemanticsIdentifier(identifier);
```

Then, in the two tests, replace the tap only:

| Test | Was | Becomes |
|---|---|---|
| `offer-kyc-gate: AppBar back arrow at stack root …` (line 107) | `await tester.tap(_appBarBackButton());` | `await tester.tap(_inBodyBackCircle('offer_kyc_gate_back'));` |
| `delivery-register-prompt: AppBar back arrow at stack root …` (line 140) | `await tester.tap(_appBarBackButton());` | `await tester.tap(_inBodyBackCircle('delivery_register_prompt_top_back'));` |

`kyc-rejected` (line 182) is unchanged.

Nothing else in the file moves: the routers, the stack-replacing `goNamed` entries and both
`expect(_locationOf(router), '/')` assertions stay byte-identical. **No assertion is weakened** —
the finder gets *stricter* (an exact identifier instead of "any `IconButton` with an arrow glyph").

Optionally retitle the two tests `AppBar back arrow` → `top-bar back circle`; not required.

### Why `find.byIcon(Icons.arrow_back)` was rejected as the fix

It matches, and the tap does navigate, but `MinTapTarget` wraps the visual child in
`IgnorePointer` so the icon itself is not the hit target — `tester.tap` emits a
"derived an Offset that would not hit test on the specified widget" warning on every run.
Measured; the identifier form is silent.

### Identifier note

`delivery_register_prompt_top_back` is a **new** id, deliberately not
`delivery_register_prompt_back`: that one is already owned by the in-body text CTA on the same
screen (asserted by JM-044 AC3 tooling), and two nodes sharing one identifier break both Maestro's
`tapOn: id` and `find.bySemanticsIdentifier`. The gate's circle could take the free
`offer_kyc_gate_back`, so it did.
