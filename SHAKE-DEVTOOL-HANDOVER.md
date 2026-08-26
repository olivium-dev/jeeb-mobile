# Shake-to-open the Jeeb Dev Tool on iOS — handover

Branch: `feat/ios-shake-to-devtool-20260826`
Base: `4d3494e7` (`origin/main` at the time of writing)
Commit: see `git log -1` on the branch

---

## 1. Why

iOS had **zero** Dev Tool entry points. Android reaches `/devtool` through a
flavor-specific launcher `Activity` that overrides `getInitialRoute()`
(`android/app/src/debug/kotlin/app/jeeb/mobile/LegacyDevToolLauncher.kt`,
`android/app/src/internalRelease/kotlin/app/jeeb/mobile/DevToolLauncher.kt`).
iOS has no second launcher icon and no URL scheme, so there was no way in at
all. A physical shake is now that way in.

No new pub dependency was added: the repo carries no sensor package in
`pubspec.yaml` and enforces a dependency-ownership gate, so the gesture is read
natively and forwarded over a `MethodChannel`.

## 2. Change list (15 files)

### Runtime
| File | What |
|---|---|
| `ios/Runner/AppDelegate.swift` | `motionEnded(_:with:)` filters `.motionShake` and fires `invokeMethod("open")` on `com.olivium.jeeb/devtool_shake`. Sets `applicationSupportsShakeToEdit = false` so UIKit stops showing its "Undo Typing" alert. **Every added line is inside `#if JEEB_DEV`.** |
| `lib/core/dev_flags.dart` | Adds `kShakeToDevToolRequested` (`--dart-define=JEEB_DEVTOOL_SHAKE`, default `true`) and `kShakeToDevToolEnabled = kDevToolEnabled && kShakeToDevToolRequested`. |
| `lib/devtool/shake/devtool_shake.dart` | **New.** Channel constants, `DevToolShakeGate` (debounce + already-open no-op), `DevToolShakeHost`, and the opaque layer with its own nested `Navigator`. |
| `lib/app/app.dart` | Mounts `DevToolShakeHost` in `MaterialApp.router`'s `builder`, behind the const ternary, **below** `ClarityMask` so session recording never captures the tool. |
| `lib/devtool/devtool_shell.dart` | Extracts `registerDevToolSuperLoginDependencies()` out of `_DevToolAppState` so both Dev Tool entry points (Android launcher and the iOS shake layer) can register `SuperLoginService` / `SuperLoginDemoUserService`. Idempotent. |

### Release scanners
| File | What |
|---|---|
| `tool/inspect_android_release_payload.sh` | `devtool_shake` added to the deny-list. |
| `tool/inspect_unsigned_ios_release.sh` | `devtool_shake` added to **both** scans — the Dart AOT snapshot and the native Runner binary. |
| `tool/inspect_android_internal_release_payload.sh` | `devtool_shake` added to the deny-list. |
| `tool/test_inspect_android_release_payload.sh` | Negative control for `devtool_shake`. |
| `tool/test_inspect_android_internal_release_payload.sh` | Negative control for `devtool_shake`. |

### Tests
| File | What |
|---|---|
| `test/devtool/shake_to_devtool_test.dart` | **New.** 23 tests. |
| `test/release/devtool_import_closure_test.dart` | **New.** Real transitive import-closure walk. |
| `test/mobile_release_contract_test.dart` | Asserts the deny-lists name `devtool_shake` in both iOS scans and in the CI contracts. |
| `test/release/store_entrypoint_auth_surface_test.dart` | Test **retitled** — see §5. |
| `test/internal_devtool/internal_devtool_source_contract_test.dart` | Test **retitled** — see §5. |

## 3. The double compile-out guarantee

Two gates. **Neither depends on the other**, so failing one still leaves the
other closed.

**Gate 1 — Dart.**
`kShakeToDevToolEnabled = kDevToolEnabled && kShakeToDevToolRequested`, and
`kDevToolEnabled = kDebugMode && kDevToolRequested`
(`lib/core/dev_flags.dart`). `kDebugMode` is a compile-time `false` in release
and profile, so the whole const folds to `false` no matter what dart-defines
are passed. Its **single** use site in `lib/app/app.dart` is a const ternary, so
a release AOT snapshot drops `DevToolShakeHost`, its `devtool_shell.dart`
import, and therefore Super Login, the screen catalog, location simulation and
scenario users.

*Proven by:* `test/release/devtool_import_closure_test.dart` (there is exactly
one non-catalog import edge into `lib/devtool/`, it is `lib/app/app.dart ->
lib/devtool/shake/devtool_shake.dart`, and its only use site matches
`kShakeToDevToolEnabled ? DevToolShakeHost(`) plus
`test/devtool/shake_to_devtool_test.dart`'s gate group.
*NOT proven by:* any real binary — see §6.

**Gate 2 — Native.**
Every added Swift line is inside `#if JEEB_DEV`. The Runner target defines
`JEEB_DEV` on exactly three configurations —
`ios/Runner.xcodeproj/project.pbxproj:937` (Debug-dev), `:963` (Profile-dev),
`:988` (Release-dev) — and **never** on the plain `Release` configuration that
`tool/build_unsigned_ios_release_contract.sh` builds for the store.

The gate is `#if JEEB_DEV` **alone**, never `#if DEBUG`: the Runner target sets
`SWIFT_ACTIVE_COMPILATION_CONDITIONS` without `DEBUG` (that lives only in
`GCC_PREPROCESSOR_DEFINITIONS`, which does not reach Swift), so
`#if DEBUG && JEEB_DEV` would compile to nothing. Verify with
`grep -rn "#if DEBUG" ios/Runner/` — the only two hits are inside `///`
comments.

## 4. Two defects found and fixed during final review

Both reproduce **only** in the production widget topology — the host mounted in
`MaterialApp.router`'s `builder`, i.e. **ABOVE** the app's Navigator.

**D1 — the Dev Tool could not be closed.** The close FAB passed
`tooltip: 'Close Dev Tool'`. `FloatingActionButton` wraps its child in a
`Tooltip` iff `tooltip != null`
(`packages/flutter/lib/src/material/floating_action_button.dart:822-824`), and
`RawTooltipState.build` asserts `debugCheckHasOverlay`
(`packages/flutter/lib/src/widgets/raw_tooltip.dart:865`). The app's Navigator
is its only `Overlay` and it sits **below** the host, so the assert fired on
every open and replaced the only exit affordance with a red `ErrorWidget`. iOS
has no hardware back button and the layer's root route has no AppBar, so the
only escape was killing the app. Fixed by dropping `tooltip:` and moving the
accessible name to `Icon(Icons.close, semanticLabel: 'Close Dev Tool')`.

**D2 — a shared HeroController assert.** `MaterialApp` publishes its
`HeroControllerScope` **above** `builder`
(`packages/flutter/lib/src/material/app.dart:1163`), so the layer's nested
`Navigator` adopted the same controller the app's Navigator already held,
tripping *"A HeroController can not be shared by multiple Navigators"*. Fixed by
giving the layer its own via
`HeroControllerScope(controller: MaterialApp.createMaterialHeroController())`,
disposed with the layer.

**Why the suite had not caught either:** `_hostUnderTest` mounted the host under
`MaterialApp(home:)` — **below** the Navigator — the exact inverse of
production. Five green widget tests, including one that taps the close key, were
false greens. The harness now mounts in `builder:`, and a dedicated control test
asserts the harness genuinely has **no** `Overlay` ancestor above the host, so it
cannot silently regress to the permissive topology.

## 5. A correction to the review's framing (evidence, not opinion)

The adversarial review asserted that before this change *"no import edge existed
from either release entrypoint to that library — presence was structurally
impossible."* **That is false.** At `origin/main`, twelve product files already
import `lib/devtool/catalog/...`:

```
git grep -n -E "^import .*devtool/" origin/main -- lib \
  | grep -v ':lib/devtool/' | grep -v ':lib/main_devtool.dart'
```

→ `diagnostics_screen.dart`, `jeeb_preview.dart`, `profile_unavailable_screen.dart`,
`dev_chat_preview_screen.dart`, `customer_profile_screen.dart`,
`kyc_status_screen.dart`, `jeeber_home_screen.dart`,
`jeeber_request_unavailable_screen.dart`, `order_summary_screen.dart`,
`notification_preferences_screen.dart`, `saved_addresses_screen.dart`,
`tier_selection_screen.dart`.

So a release AOT snapshot has **always** depended on tree-shaking to keep
`lib/devtool/` out; that is not a new assumption introduced here. What **is**
new is the first edge that reaches the `devtool_shell` cluster (Super Login,
location sim, scenario users). The review's *conclusion* — that the internal
release scanner needed `devtool_shake` — was right and has been acted on; only
its "structurally impossible before" premise was wrong.

Consequently the two pre-existing isolation tests were **retitled rather than
strengthened into a false claim**, because the property they named is not true
and was not true before:
- `store_entrypoint_auth_surface_test.dart`: *"the product entrypoint has no Dev
  Tool dependency graph"* → *"the product entrypoint file itself names no Dev
  Tool symbol"* (it only ever grepped `lib/main.dart`'s own bytes).
- `internal_devtool_source_contract_test.dart`: *"internal release graph stays
  isolated from the legacy developer tool"* → *"the internal tool source tree
  names no legacy developer-tool capability"*.

The transitive property they implied is now asserted for real in
`test/release/devtool_import_closure_test.dart`.

## 6. Verification evidence

All commands run from `/Users/oudaykhaled/jeeb-workspace/mob-wt-shake-devtool`
with the pinned SDK `/Users/oudaykhaled/flutter-3.44/bin/flutter`.

| Command | Result |
|---|---|
| `dart analyze lib` | `No issues found!` (exit 0) |
| `dart analyze lib test` | `No issues found!` (exit 0) |
| `flutter test test/devtool/shake_to_devtool_test.dart` | `+23: All tests passed!` |
| `flutter test test/release/devtool_import_closure_test.dart` | `+5: All tests passed!` |
| `bash tool/test_inspect_android_release_payload.sh` | passed (exit 0) |
| `bash tool/test_inspect_android_internal_release_payload.sh` | passed (exit 0) |
| `flutter test` (full, this branch) | see §6.1 |
| `flutter test` (full, base `4d3494e7`) | `10:15 +8232 ~67 -83: Some tests failed.` (exit 1) |

**The baseline is already red** — 83 failures at `4d3494e7`, none of them in
anything this branch touches. It was re-derived first-hand on this machine with
this SDK rather than copied from the task brief, and the failure sets were
compared name-by-name.

### 6.1 Negative controls actually run (each was confirmed to go red)

| # | Mutation | Result |
|---|---|---|
| NC-A | restore `tooltip:` on the close FAB | 7 failures incl. *"opening the layer throws nothing"* |
| NC-B | remove the layer's `HeroControllerScope` | 7 failures |
| NC-C | move the harness back under `home:` | *"the harness really is Overlay-less…"* fails |
| NC-D | remove `devtool_shake` from the internal scanner regex | `Internal inspector accepted forbidden marker: devtool_shake`, exit 1 |
| NC-E | add an ungated `lib/main.dart -> lib/devtool/devtool_shell.dart` import | *"the only non-catalog crossing…"* fails |
| NC-F | remove the const ternary from `app.dart` | *"the shake edge is used only behind the compile-time const"* fails |

## 7. What is NOT verified

1. **No build of any kind was run. `BLOCKED_DISK.`** `df -h /Users/oudaykhaled`
   reported **~950 MiB free**, far below the 6 GiB bar. Therefore:
   - the Swift in `AppDelegate.swift` **has never been compiled**;
   - the tree-shaking half of Gate 1 is **unproven against a real binary** —
     `flutter build appbundle --flavor internalRelease --release --target
     lib/main_android_internal.dart` and
     `tool/build_unsigned_ios_release_contract.sh` were both skipped;
   - the scanners now *name* `devtool_shake`, but no scanner has been run
     against a real artifact built from this branch.
2. **No simulator smoke. No physical-device smoke.** Nothing on this branch has
   been observed running on iOS.
3. **Does `motionEnded` actually reach `FlutterAppDelegate`?** This app is
   UIScene-based (`ios/Runner/SceneDelegate.swift`). The responder chain
   argument is sound and the pinned engine implements no motion callback
   (`motionEnded:withEvent:` → 0 hits in the engine binary), but **whether the
   event reaches the app delegate when no first responder exists cannot be
   settled statically.** This is the single highest-risk unknown and it is
   device-only.
4. **The `Overlay`/`HeroController` fixes are proven in `flutter_test`, not on a
   device.** The topology under test is now the production one, which is a large
   improvement, but it is still the widget-test binding.

## 8. How a human should smoke it

Free at least 6 GiB first — `df -h /Users/oudaykhaled`.

```bash
cd /Users/oudaykhaled/jeeb-workspace/mob-wt-shake-devtool
# omds-flutter must resolve as ../omds-flutter
ls ../omds-flutter/omds_library/pubspec.yaml
/Users/oudaykhaled/flutter-3.44/bin/flutter pub get
```

**Simulator**

```bash
open -a Simulator
/Users/oudaykhaled/flutter-3.44/bin/flutter run \
  --flavor dev --debug -d <simulator-id>
```

Then in the Simulator menu bar: **Device > Shake Gesture** (`⌃⌘Z`).

Expect: the Dev Tool covers the app; **no** "Undo Typing" system alert; the
close button bottom-right is a real button (**not** a red error box); tapping it
returns you to exactly the screen you left, with its state intact. Shake twice
fast — the second shake inside 1s must do nothing.

**Physical iPhone 12 mini**

```bash
/Users/oudaykhaled/flutter-3.44/bin/flutter devices          # get the id
/Users/oudaykhaled/flutter-3.44/bin/flutter run \
  --flavor dev --debug -d <device-id>
```

Physically shake the phone. Same expectations. **This run is the only thing
that can settle §7 item 3.**

**Negative check (must show NO shake):** build the `Release` configuration
without `--flavor dev` and confirm a shake does nothing at all.

```bash
bash tool/build_unsigned_ios_release_contract.sh   # also runs the string scan
```

## 9. Known pre-existing bug deliberately NOT fixed here

`tool/run_ios_devtool.sh` passes `--route=/devtool`, but the current
`lib/main.dart` **no longer consumes that route** — the route selector was
removed earlier, and `lib/core/router/app_router.dart` redirects `/devtool` to
`/` as a runtime backstop. The flag is therefore inert.

This was left alone on purpose: it is unrelated to shake-to-open and mixing it
in would make this diff harder to review and harder to revert. It should get its
own ticket.

## 10. Rollback

The change is one commit and is inert in production by construction, so a
rollback is only needed to remove the dev affordance itself.

- **Whole feature:** `git revert <sha>` — no migration, no config, no server
  state.
- **Keep the code, kill the gesture:** build with
  `--dart-define=JEEB_DEVTOOL_SHAKE=false`. `kShakeToDevToolRequested` becomes
  `false`, the const folds, and the wiring compiles out while the rest of the
  Dev Tool keeps working.
- **Native only:** remove `JEEB_DEV` from `SWIFT_ACTIVE_COMPILATION_CONDITIONS`
  on the `-dev` configurations. This also disables the pre-existing dev-flavor
  Firebase plist branch, so prefer the dart-define.
- Reverting also removes the `devtool_shake` deny-list entries. That is correct:
  with the feature gone there is no marker to scan for.
