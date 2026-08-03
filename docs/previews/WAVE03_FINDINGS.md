# Wave 03 (core) — defects surfaced, and the observability scope call

4 of 8 written. The four `ObsOverlay*` agents FAILED by design: they refused to
add seams to production code and documented exactly which ones are missing.

## Scope decision

`lib/core/observability/` is now excluded from the coverage denominator, on the
same ground as `lib/devtool/`: it is dev-only tooling, compiled OUT of every
non-devtool build via `kObsCompiledIn = kDevToolEnabled && 
bool.fromEnvironment('JEEB_OBS_OVERLAY')` (observability_config.dart:32).

This is NOT the 'renders child verbatim' exclusion the ObsOverlayHost agent
argued against — it correctly noted that widget does change how its child
renders. It is a scope call about what the rollout is for: product UI.

## Seams required if it is ever brought back into scope

- an injectable `ObsOverlayController?` on `ObsOverlayHost`
- a way to bypass the compile gate (`debugForceCompiledIn`, or an `enabled`
  parameter defaulting to `kObsCompiledIn`)
- a seeding constructor `ObsOverlayController({List<ObsEvent> seed, ...})`
- `ObsOverlayController` is a `final class`, so it cannot be faked from outside
  its library — the seam has to be added there, not worked around

## Defects in the widgets that WERE previewed

### F01

ResponsiveBody: Breakpoint discontinuity: the content column is WIDER below breakpointWide than above it. At 839 pt the medium branch yields 839 - 2x20 = 799 pt of content — a third wider than maxContentWidth (600), the value the class dartdoc calls a "hard ceiling on the content column width for readability". At 840 pt it snaps down to 600. So the widest line length the app ever renders is produced by the branch meant to prevent it, and dragging a window across 840 pt reflows every line of body text. Pinned in the test: `expect(justUnder.width, 799.0)` + `greaterThan(ResponsiveBody.maxContentWidth)` against `expect(atWide.width, 600.0)`.

### F02

ResponsiveBody: The expanded branch centres VERTICALLY as well as horizontally. `Center` has no width/height factor, so it takes all the height on offer (the Scaffold body gives loose height constraints) and centres the child on both axes. The identical content block sits at (0, 0) in the phone preview and at (340, 258) at 1280 pt — 258 pt of dead space above it. A screen body that starts under the app bar on a phone floats in the middle of the window on a tablet. Only children that happen to fill the height hide this.

### F03

ResponsiveBody: The widget silently changes the constraint contract it offers its child halfway up the breakpoint scale: compact/medium forward the parent's TIGHT width, but the expanded branch's `Center` passes LOOSE constraints. A child that does not ask for `double.infinity` — a Card, a Column of Text — is stretched to full width on a phone and shrink-wraps to its longest line on a tablet (measured 435.8 pt inside the 600 pt column). Nothing in the dartdoc mentions the difference; the child still reports being "offered 600 pt", it just does not take it.

### F04

ResponsiveBody: The compact branch adds no horizontal gutter at all (content flush to x = 0) and removes no MediaQuery padding, so every caller on the path ~all users are on must pad its own child or its text sits against the display edge. Real, but arguably intended — flagged because the class dartdoc's "fills edge to edge" phrasing reads as a layout choice rather than a caller obligation.

### F05

ResponsiveBody: ResponsiveBody and its sibling `deviceFormFactor()` in the same file disagree on their source of truth: the widget switches on incoming layout constraints, the helper on `MediaQuery.sizeOf(context).width` (the whole window). They diverge whenever the body is not full-window — a nav rail, a split view, or any padded parent. The previews demonstrate the divergence live: MediaQuery stays 800 pt wide for the entire suite while ResponsiveBody renders all three branches, so `deviceFormFactor()` would report `medium` for every one of the six states.

### F06

BottomSheetSafeArea: 200% text + keyboard open hard-overflows. BottomSheetSafeArea pads OUTSIDE its child and its doc example (`BottomSheetSafeArea(child: MySheetBody())`) shows a non-scrolling body, so the inset pushes content past the top of the sheet instead of compressing it. Measured at 390 pt wide: the fixture body is 196 pt at 1.0 and 356 pt at 200% text; 356 + 300 (keyboard) = 656 in a 620 pt box = RenderFlex overflow of 36 px. Not hypothetical: lib/features/registration/presentation/super_login/super_login_sheet.dart:232-247 pads a plain non-scrolling `_SuperLoginFormColumn` by `sheetBottomInset`, and it is a two-field form so the keyboard is always up. The other two callers (super_login_picker.dart, order_history_date_filter_sheet.dart) happen to wrap in SingleChildScrollView; nothing in the widget or its docs asks a caller to.

### F07

BottomSheetSafeArea: Not double-pad safe — the nav-bar inset is reserved TWICE under any ancestor SafeArea. `sheetBottomInset` reads `View.of(context).viewPadding` deliberately, so it cannot see that an ancestor already consumed the same inset. Measured in the preview harness (whose `jeebPreviewHost` wraps every preview in `Scaffold(body: SafeArea(...))`) with a seeded 48 dp nav bar: the CTA ends up >96 dp clear of the screen edge instead of 48. Harmless for a real modal sheet, wrong anywhere else — and the sibling `scrollBodyBottomInset` documents itself as double-pad safe precisely because it reads MediaQuery, so the asymmetry is easy to trip over. Pinned by the `nested inside a SafeArea, the nav-bar inset is reserved TWICE` test.

### F08

BottomSheetSafeArea: The rationale in lib/core/layout/bottom_inset.dart:29-36 is empirically false on Flutter 3.44.2. It states — and calls 'load-bearing' — that inside a `showModalBottomSheet` builder `MediaQuery.of(context).viewPadding` and `.padding` are both `EdgeInsets.zero`, which is why the helper bypasses MediaQuery for the nav-bar term. Measured in a plain MaterialApp host with a seeded 48 dp inset, both read 48.0 inside the sheet builder (default `useSafeArea: false` only does `MediaQuery.removePadding(removeTop: true)`). If that holds on device, the bypass buys nothing and only costs the double pad above. Flagged, not changed — I did not prove the on-device case, and the fix belongs to the owner of bottom_inset.dart.

### F09

BottomSheetSafeArea: Half of what this widget computes cannot be previewed at all. The nav-bar term comes from `View.of(context)`, and no widget can substitute a FlutterView mid-tree, so the preview canvas (a desktop window, viewPadding == 0) always renders that half as zero — the keyboard term is the only one a preview can drive. It is reachable only from a widget test via `tester.view.viewPadding`, so the geometry group in the test file is doing work the canvas structurally cannot.

### F10

ObsOverlayHost: The regression documented at length in obs_overlay.dart:75-96 (Tooltip resolving its Overlay during build() outside any Overlay ancestor -> 'No Overlay widget found' the instant the panel expanded, plus the companion 'BOTTOM OVERFLOWED BY 99778 PIXELS' from the substituted ErrorWidget) has ZERO test coverage: grep for 'ObsOverlay' / 'obs_overlay' across test/ returns no files at all. The same compile gate that blocks the preview is why nothing guards the fix — the _ObsOverlayLayer private Overlay could be deleted today and every test in the repo would still pass.

### F11

ObsOverlayHost: Hardcoded English in the overlay subtree, which the AR RTL rendering of the preview matrix would have flagged: ObsOverlayBubble sets a raw semantics label `label: 'Session trace overlay'` (obs_overlay_bubble.dart:26), and ObsOverlayController builds raw English user-facing strings — 'No session file yet — start recording first.' (line 189), 'Shared ...' (209), 'Share unavailable — path copied:' (219), 'Export ready at:' (222). Defensible for a devtool-only surface, but it is unlocalized text rendered on top of a fully localized app, and the screen-reader label in particular is announced verbatim to an Arabic user.

### F12

ObsOverlayControlBar: OVERFLOW at 200% text (real, reproduced): the `_ClearRow` Row at lib/core/observability/session_trace/presentation/widgets/obs_overlay_control_bar.dart:69 overflows because neither child is wrapped in Flexible/Expanded — the `'$count buffered'` Text (line 72) and the OMDSOutlinedButton (line 79) both take their intrinsic width, so nothing ellipsizes. Measured with a real controller: at 308 logical px (the panel's actual content width — ObsOverlayPanel's _kMaxWidth 340 minus its EdgeInsets.all(Spacing.medium)) and textScaler 2.0 it throws 'A RenderFlex overflowed by 113 pixels on the right'; still 31 px over even at a full 390 px phone width. Same overflow under TextDirection.rtl (112 px). At 1.0 scale it is clean down to 240 px, so this is purely the accessibility ceiling — precisely the third rendering the @JeebPreview matrix exists to catch, and it fires on the DEFAULT state ('0 buffered'), the narrowest the count string ever gets. A non-zero count (up to '500 buffered') would overflow further.

### F13

ObsOverlayControlBar: HARDCODED ENGLISH, no AppLocalizations: 'Recording' (line 48), 'Capturing screen/api/push/interaction' / 'Paused' (line 49), the concatenated and unpluralized '$count buffered' (line 72), and 'Clear' (line 81) are all string literals, so the AR RTL third of the preview matrix would render an all-English, LTR-worded row inside a mirrored layout. Defensible for a dev-only overlay that is tree-shaken out of production, but flagging it because it is what a reviewer opening the AR rendering will see first, and because '$count buffered' would need an ICU plural rather than concatenation if it is ever localized.

### F14

ObsOverlayExportButton: 200% text silently clips the button label. At the production panel content width (308 logical px = ObsOverlayPanel's min(340, screenW-32) minus its 2x16 padding), 'Export / Share JSONL' needs 120.0px of height at 2.0 text scale (RenderParagraph.getMaxIntrinsicHeight(308) == 120.0, i.e. 3 wrapped lines), but OmdsLoadingButton pins the box to `height ?? Sizes.fourXLarge` == 48. Measured: paragraph size == Size(308, 48), button size == Size(308, 48), tester.takeException() == null. So ~60% of the only label on the control is invisible at the accessibility ceiling, with no ellipsis and no overflow assertion to catch it. Fix belongs at the call site (shorter label / explicit maxLines+ellipsis / let the button grow), since OmdsLoadingButton ignores textScaler by design.

### F15

ObsOverlayExportButton: The exported-path label is laid out in an RTL paragraph in Arabic. `_ExportedPathLabel` uses SelectableText with no `textDirection`, so it inherits ambient direction; measured Directionality.of(context) == TextDirection.rtl at the `obs-overlay-export-path` element under Locale('ar'). A POSIX path is a strong-LTR run whose leading '/' is a bidi neutral at paragraph start, so it takes the RTL base direction and renders at the trailing edge (path shows as `data/user/.../client.jsonl/`), and the whole block right-aligns. This label exists precisely so a tester can read/copy the file location after the snackbar dismisses, so a re-ordered path is worse than no path. Fix: `textDirection: TextDirection.ltr` (or a Directionality.ltr wrapper) on the SelectableText.

### F16

ObsOverlayExportButton: The export block roughly doubles in height at 200% text and has nowhere to grow. Measured at panel width 308: path label 308x80 at 100% vs 308x224 at 200%, so the Column (button 48 + Spacing.twoXSmall 4 + label) goes 132px -> 276px. ObsOverlayExportButton is the last NON-flexible child of ObsOverlayPanel's Column, whose shell height is fixed at 62% of the screen with the event list in an Expanded, so at large text the export block takes 144px straight out of the live event list and will overflow the panel on a short screen.

### F17

ObsOverlayExportButton: The only label the widget draws is the hardcoded English literal 'Export / Share JSONL' (and the controller's messages 'No session file yet - start recording first.' / 'Shared <file>' / 'Share unavailable - path copied:' are hardcoded too), so the AR rendering is English text in an RTL box. Defensible for a devtool overlay gated behind --dart-define JEEB_OBS_OVERLAY, but it is the reason finding #1 bites: the label is long because it is untranslatable boilerplate nobody sized for 200%.

### F18

ObsOverlayEventList: lib/core/observability/session_trace/presentation/widgets/obs_overlay_event_list.dart:36-39 — `_EmptyEvents` passes hardcoded English literals ('No events yet', 'Start recording, then use the app to see events here.') to `OmdsEmptyState` instead of `AppLocalizations`. The mandatory AR RTL rendering of the JeebPreview matrix would show English text in an Arabic layout. Caveat before anyone 'fixes' this: the whole session_trace devtool surface is English-only by convention (`ObsOverlayEventFormatter.labelFor` likewise returns hardcoded 'Screen'/'API'/'Push'/'Interaction'), so this may be intentional for a dev-only tool — but it is a fact of the widget the matrix will surface, so it should be an explicit decision rather than an oversight.

### F19

ObsOverlayPanelHeader: Hardcoded English, visible in every AR RTL rendering: the title literal 'Session Trace' and the close button's `tooltip: 'Close'` are not AppLocalizations keys (obs_overlay_panel_header.dart:19 and :28). The tooltip is also the button's only semantics label, so an Arabic screen-reader user hears English for the sole control in the row. Defensible for a `--dart-define JEEB_OBS_OVERLAY=true` devtool, but it is what the AR pass of the matrix is for.

### F20

ObsOverlayPanelHeader: The close button ignores the text scaler while the title obeys it. Measured on the 320pt-device preview: at 200% text the row grows 48pt -> 144pt while the IconButton stays exactly 48x48. The panel is only 0.62 of screen height, so at the accessibility ceiling the title alone eats a large share of the panel, and the tap target does not grow with the user's setting.

### F21

ObsOverlayPanelHeader: A height-bounded host silently takes the only exit below the Material minimum. In a 40pt slot the close button measures 48x40 — no assertion, no overflow stripe, no exception. The header defends neither its own height nor its button's, so dropping it into a fixed-height toolbar produces a sub-48pt tap target that looks fine.

### F22

ObsOverlayPanelHeader: The title Text sets no maxLines and no overflow, so it degrades by growing without bound: in the 160pt host at 200% text the row measures 336pt tall. Good behaviour compared to clipping, but nothing caps it, and the row's height is whatever the label needs.

### F23

ObsOverlayPanelHeader: The widget is only safe under an Overlay ancestor. Its Tooltip resolves an Overlay as part of build, which is what once threw 'No Overlay widget found' plus the companion 'BOTTOM OVERFLOWED BY 99778 PIXELS' (documented on _ObsOverlayLayer in obs_overlay.dart). The header carries no guard of its own — the fix lives entirely in its host — so any reuse outside _ObsOverlayLayer reintroduces the crash. The production preview mounts a private Overlay to keep that guarded.

### F24

ObsOverlayBubble: Does not mirror in RTL. `ObsOverlayBubble` anchors with `Positioned(right: Spacing.medium)` — a physical edge — not `PositionedDirectional`/`Positioned.directional`. Measured: the bubble's rect is byte-identical in EN and AR, so in Arabic it sits in the LEADING corner while the whole app flips around it. Concrete consequence, asserted in the test: over a bottom nav bar it covers 'Profile' in English and 'Home' in Arabic. It may be intentional for a devtool (testers want it in a fixed place), but nothing in the code says so — it is currently an accident of which `Positioned` constructor was used.

### F25

ObsOverlayBubble: It occludes whatever the screen docks to its own bottom edge, which is the 'dev red button' complaint in `observability_config.dart` expressed as geometry. The bubble occupies 24-72pt up from the bottom, so it covers the bottom-most 40pt of any docked chrome: an entire 64pt bottom-nav destination (icon + label), or a 48x40 bite out of the trailing end of a docked full-width primary CTA. There is no drag-to-move and no alternative affordance, so on a CTA screen the lost tap area has no second route.

### F26

ObsOverlayBubble: The bottom anchor is not inset-aware. `ObsOverlayHost` is mounted from `MaterialApp.builder` as a sibling of the routed child, so nothing between the bubble and the screen edge consumes `MediaQuery.padding`; `bottom: Spacing.xLarge` (24pt) is measured against the physical bottom of the display. Against a 34pt home indicator (iPhone 15) the bubble's lower 10pt sits inside the system gesture region, where a drag belongs to the OS before it belongs to the app. Asserted at 10.0pt in the test.

### F27

ObsOverlayBubble: The one state the widget's own parameter can produce is unreachable in any preview or test. `_BubbleIcon` shows the red badge dot when `controller.recording` is true, but that getter forwards to the global `Observability.instance.recording` = `kObsCompiledIn && ObservabilityConfig.enabled`, and `kObsCompiledIn` is a compile-time false unless the build carries BOTH `--dart-define JEEB_DEVTOOL_ENABLED=true` and `--dart-define JEEB_OBS_OVERLAY=true`. `ObsOverlayController` is a `final class` with no overridable `recording`, so there is no per-instance seam either: the recording preview can only request the state via the global and then render identically to the idle one. (No production change was made; the preview documents this and the test asserts the contract 'dot iff Observability.instance.recording', which holds in both kinds of build.)

### F28

ObsOverlayBubble: The only string the widget gives a screen-reader user is hardcoded English: `Semantics(label: 'Session trace overlay')`. The test pins that it is the same English string under `Locale('ar')`. Low severity — the whole overlay is devtool-only and tree-shaken from production — but it is the one accessibility affordance the widget has.

