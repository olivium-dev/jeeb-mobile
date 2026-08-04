# Wave 08 (shell) — defects surfaced by the previews

8/8 written, 45 previews. The most serious wave so far: ChatTab appears to be
structurally empty against the live gateway, and EarningsTab breaks on the
launch market's own currency. Recorded, not fixed.

## F01

EarningsTab: _PeriodFilterRow (lib/features/earnings/presentation/earnings_dashboard_screen.dart:183) is a bare Row of three OmdsChips with no Wrap, no horizontal scroll and no Flexible. In a 390 dp box at 200% text it clips by 330 dp (EN) / 342 dp (AR) against 358 dp of content width — the whole 'This month' pill and part of 'This week' are off the trailing edge, and because the row cannot scroll there is NO gesture that brings them back, so a large-text jeeber cannot change period at all. It clips in every state, including the empty one where the pills are the only control besides pull-to-refresh. At 100% the measurement is already 42 dp over (test font is wider than Inter, so treat that number as 'zero margin' rather than a shipping break).

## F02

EarningsTab: _FeesPaidCard (earnings_dashboard_screen.dart:298) lays out Icon + Expanded(label column) + Text(amount); the amount is the only non-flex child, so it is measured against an unbounded main axis and takes what it wants. With a normal Lebanese amount (LBP 1,875,000.00) the Expanded column is starved to 3.3 dp: 'Platform fees paid' becomes a one-glyph-per-line vertical ribbon and the SAME card grows from 172 dp tall (USD) to 1028 dp, pushing the stats row, member-since and breakdown off screen. Nothing throws — no RenderFlex overflow, no test failure — so only looking at it catches it. LBP is the launch market's currency, not a stress fixture.

## F03

EarningsTab: _MemberSinceRow._formatDate (earnings_dashboard_screen.dart:461) calls a bare DateFormat.yMMM(), which resolves through Intl.getCurrentLocale(); nothing in the app ever sets Intl.defaultLocale, so it is en_US in every locale. In the AR RTL rendering the row reads 'عضو منذ Nov 2025' — the label translates, the month does not, and it is the ONLY Latin-script string in the entire Arabic screen.

## F04

EarningsTab: Both of the tab's waiting branches render Center(child: OmdsLoadingState()) with no message: the session read in EarningsTab and the dashboard's own in-flight read are pixel-identical AND announce nothing, so a screen-reader user is told nothing at all while the tab decides whether they even have an earnings account. (The preview 'Session resolving' renders zero Text widgets — asserted in the test.)

## F05

EarningsTab: EarningsCubit._mapError (lib/features/earnings/application/earnings_cubit.dart:72) builds hardcoded ENGLISH error strings ('Unable to connect. Check your internet.', 'Server error. Please try again later.') into state.errorMessage, but EarningsDashboardScreen ignores that field and renders the localized earningsLoadFailed. The English copy is dead but reachable — any future surface that displays state.errorMessage ships unlocalized text.

## F06

ChatTab: Errors are swallowed and render as an empty inbox: `_loadConversations`'s `on DioException { _loading = false }` (chat_tab.dart:69) leaves `_conversations` empty, so a 503 produces the SAME `OmdsEmptyState` — same icon, same "No conversations yet." — as a genuinely empty inbox. No error copy, no retry button, no `RefreshIndicator`. The `Gateway 503 · reads as empty` preview is pixel-identical to `Empty · gateway returned none`; the test can only tell them apart at the transport (503 serving one row the user never sees).

## F07

ChatTab: The tab is structurally always empty against the live gateway. It `continue`s past every row whose `conversationId` is null or empty (chat_tab.dart:52-53) with no counter and no diagnostic — but the real `/v1/requests` row is `{id, createdAt, pickup, dropoff, status, tier, amount}` and carries NO `conversationId` and NO `title` (see `dio_order_repository._parseOrder`, the sibling consumer of the same endpoint). The `Real row shape · 1 of 3 survives` preview renders that: three active requests in, one row out, silently.

## F08

ChatTab: Hardcoded English reaches the user in Arabic. `conv.status` is printed verbatim from the wire ('InTransit', 'Accepted', 'AtDoor', 'awaiting_jeeber_acceptance') and a titleless row falls back to the literal `'Delivery'` (chat_tab.dart:57) — neither goes through `AppLocalizations`. The test pins this under `Locale('ar')`: the AR rendering of an Arabic-first product shows `InTransit` / `Delivery`.

## F09

ChatTab: The load runs exactly once, from `initState`, and nothing re-arms it: there is no pull-to-refresh, no retry CTA, and no push/refresh-signal subscription. Whatever the first frame resolved to — empty, stale, or a swallowed failure — is what the user has until the tab's State is re-created. In the `Loading · request in flight` preview the spinner is therefore the rest of the session if the gateway never answers.

## F10

ChatTab: `ChatTab.activeDeliveryCardKey` names a semantic ('active delivery') but is assigned positionally to `index == 0` (chat_tab.dart:97). In the `Real row shape` preview the only surviving row is the gateway's THIRD item and it still carries the key — any consumer treating that key as 'the active delivery' is really getting 'whatever sorted first'.

## F11

ChatTab: Not previewed, found while shaping the payload fixtures: a malformed envelope is an unhandled crash into a permanent spinner. `response.data?['items'] as List? ?? []` (chat_tab.dart:48) throws a `TypeError`, not a `DioException`, when `items` arrives as an object, and `on DioException` is the only catch — so `_loading` is never cleared. I left this out of the preview set deliberately: it would surface as an unhandled async error in the render test rather than as a reviewable frame.

## F12

HomeTab: `_ClientHomeTabBar` (lib/features/home_client/presentation/client_home_screen.dart:431) overflows at 200% text on a phone-width screen. It is a bare `Row` of two `OmdsChip`s inside a 16 dp gutter — no `Wrap`, no `Flexible`, no horizontal scroll — so at `textScaleFactor: 2.0` in a 390 dp box it overflows by 266 dp under EN and 278 dp under AR (the Arabic chip labels are longer). The 'Pending Requests' chip alone measures 418 dp against 358 dp of available width. Every READY state of the tab inherits this; only the loading and failed layouts escape, because they drop the chip row entirely. This is the one overflow that is invisible from the sub-tab previews, because the chip row belongs to the composition rather than to either tab.

## F13

HomeTab: The cold-load header loses a name it already has. `_LoadingLayout` (client_home_screen.dart:272) hardcodes `ClientHomeGreeting(name: null, …)`, so the header renders 'Welcome back' even though `ClientHomeCubit.load()` emitted `greetingName` into state on the same frame. `_FailedLayout` nine lines below correctly passes `state.greetingName`, which is what makes this look like an oversight rather than a decision — the visible effect is a greeting that flips from generic to 'Hello, Layla' the moment the load lands. Pinned in the Loading render test so a fix is a two-line change there.

## F14

HomeTab: The pending card's `pending-server-status` row (lib/features/home_client/presentation/tabs/pending_requests_tab.dart:303) overflows by a further 201 dp at 200% text at 390 dp width, once per rendered card. Reproduces with a short two-word title, so it is not a fixture artifact.

## F15

HomeTab: The replies card's CTA row (`_RepliesActions`, lib/features/home_client/presentation/widgets/replies_card.dart:154) overflows by 208 dp at 200% text at 390 dp width — the 'Accept' and 'Check Offers' pills are `IntrinsicWidth` children of an end-aligned `Row` with no wrap. This confirms, with a measurement, the risk `replies_tab_preview.dart` already flags in prose.

## F16

DashboardTab: jeeber_feed_card.dart:552 — the incoming-request footer is Wrap(spaceBetween){tier chip, Row(min){Ignore, Offer}}. A Wrap cannot split one child and neither button is Flexible/ellipsizing, so the pair claims its intrinsic width and overflows. Measured at 360 logical px (Galaxy S22, the team's test device): AR 100% overflows by 32 px — i.e. every Arabic jeeber on a 360 px phone, today, not an accessibility ceiling. EN 200% = 145 px, AR 200% = 228 px. At 390 px the AR 100% case shrinks to 2 px, which is why it has been easy to miss.

## F17

DashboardTab: active_deliveries_banner.dart:150 — the collapsed summary row is Row{Expanded('Your active deliveries', 2-line ellipsis), 'View all (N)' button}. The button is neither Flexible nor ellipsizing, so at 200% text it takes its intrinsic width and the row overflows by 85 px (EN) / 84 px (AR) at 360 px. Same shape and same fix as JEBV4-286 applied to the sibling banner.

## F18

DashboardTab: The register-prompt destination (JeeberUnregisteredView -> OmdsEmptyState) overflows by 180 px on the bottom at EN 200% text in a 360x700 body — the real DELIVERY-tab slot on an S22 — and is silently clipped because nothing scrolls. AR RTL does not reproduce it (the shorter Arabic headline saves lines), so this is an English-only accessibility break that an Arabic-first spot check would miss. Reached by BOTH the `none` and `rejected` gate branches.

## F19

DashboardTab: JeeberKycStatus.rejected is terminal (D52/D87), yet the tab body renders a fully actionable 'Register now' CTA — chaining into the onboarding wizard the jeeber was just rejected from — for the frame before _GateScoped's post-frame redirect fires. With no GoRouter in scope (GoRouter.maybeOf == null) the redirect no-ops and that frame is permanent, which is what makes it visible in the preview. This frame belongs to DashboardTab, not to the views it hosts.

## F20

DashboardTab: An availability-read failure replaces the ENTIRE tab body with the icon/line/Retry block: the greeting, the request feed and the active-deliveries card are all discarded even though those three reads succeeded. A jeeber mid-delivery loses their only in-app entry to the won order because an unrelated GET /v1/availability failed (on device the usual cause is a client-scoped bearer 403, JEBV4-271/279).

## F21

OrdersTab: order_history_screen.dart:270 — the error branch is returned BARE into the TabBarView (`OmdsErrorState`, a mainAxisSize.min Column of 64pt icon → title → message → retry button) with no scroll and no pull-to-refresh, while the sibling empty branch at :281 is wrapped in `OmdsPullToRefresh → ListView`. When the column outgrows the tab's list area it is a hard bottom RenderFlex overflow and 'Try again' — the only recovery affordance on that state, since the pull gesture is absent — is clipped away with it. Measured at 390x560: fits at 1.0x; at 1.6x the button's bottom is 27pt past the viewport; at 2.0x the whole button starts 134pt BELOW the viewport and is unreachable (rect top 694 vs viewport 560). AR overflows too (31px @1.6x, 114px @2.0x). Font-metric caveat: `flutter test` substitutes a wide monospaced font, so treat the exact pixel counts as an upper bound — but the structural defect (no scroll, no pull, clipped sole CTA) is font-independent.

## F22

OrdersTab: Same widget, default text scale: the error state already overflows on short viewports — 28px over at 390x420 and 68px over at 390x380 (SE-class list area) at 1.0x text. So this is not only a large-text problem.

## F23

ProfileTab: BecomeJeeberCard (rendered by ProfileTab) overflows at 200% text: 'A RenderFlex overflowed by 15 pixels on the right' at 390 pt and 'by 85 pixels' at 320 pt. Its _CardContent is one unwrapped Row (avatar + Expanded(text) + OmdsPrimaryButton) with no wrap/Wrap/Flexible on the CTA. Confirmed the card is the sole source: the Jeeber state, which differs only in that the card collapses to SizedBox.shrink(), is clean at 200% in both EN and AR.

## F24

ProfileTab: The same Row starves its text column at 1x text scale, before any accessibility setting. Measured at 390 pt: the Expanded column gets ~111 pt, 'Become a Jeeber' wraps to 3 lines and the card is 204 pt tall instead of the ~80 pt its design implies. At 320 pt the column collapses to ~41 pt, the title wraps to 7 lines and the card is 168 pt tall. The avatar and the CTA never yield, so every pixel lost comes out of the text.

## F25

ProfileTab: The three settings sections have no horizontal inset at all: 'Language' renders at Rect.fromLTRB(0.0, 236.0, 176.0, 264.0) and the 'English' row title at x = 0 — flush against the screen edge — while the Become-a-Jeeber card directly above them is inset by Spacing.medium (16). ProfileTab's ListView padding is EdgeInsets.symmetric(vertical: ...) only, OmdsSettingsSection adds no horizontal padding, and each OmdsSettingsRow is built with contentPadding: EdgeInsets.zero. ProfileTab is an orphan with no host, so no parent supplies the missing inset either.

## F26

ShellHeaderActions: HIT-TARGET COLLISION on the Requests tab: the shell overlays ShellHeaderActions at PositionedDirectional(top:0, end:Spacing.xSmall) (shell_screen.dart _HeaderedTab, lines 301-325) over a HomeTab body whose first child is ClientHomeGreeting, which reserves no top inset and puts its filled '+' create-request button in the same corner. Measured at 390 dp: '+' = Rect.fromLTRB(326,16,374,64), bell = Rect.fromLTRB(334,0,382,48) -> 40x32 dp intersection (~55% of the '+' button), plus 8x32 against the wallet chip. The overlay is the LAST child of the Stack, so it also wins the hit test: a tap on the top-trailing corner of '+' opens /notifications instead of starting a request. Still overlapping at 200% text ('+' only drops to y 20).

## F27

ShellHeaderActions: TEXT UNDER THE ICONS, both greeting hosts, because Material(color: Colors.transparent) means there is no scrim. Client (orders_home): the greeting line is shrink-wrapped to LTRB(44,26,314,54) at 390 dp, and the wallet glyph paints 298-322 x 12-36 - so the ellipsis of a long name is drawn under the wallet icon. Jeeber (delivery_tab): JeeberHomeGreeting's line is a FULL-width Text at LTRB(16,16,374,44) while the actions occupy 286-382, so a long first name runs beneath both icons before it ever ellipsizes.

## F28

ShellHeaderActions: The 56 dp clearance is an unenforced per-host convention, not a shell guarantee. Only CustomerProfileHeader reserves it (EdgeInsetsDirectional top: Sizes.fiveXLarge, with a comment saying it is there 'to clear the shell-overlaid header actions'); ClientHomeGreeting and JeeberHomeGreeting both use Spacing.medium and reserve nothing. Two of the three production hosts are wrong, which points the fix at the shell injecting a top content inset (the way _NavBarContentInset already injects the bottom one) rather than at each screen remembering.

## F29

JeeberTabEmptyState: No scroll view + a hard-coded 80px icon means the CTA is CLIPPED AWAY on a 320pt phone at 200% text. `JeeberTabEmptyState` is `Semantics > Center > OmdsEmptyState`, and `OmdsEmptyState` is a bare `Column(mainAxisSize: min)` with no `SingleChildScrollView` anywhere. Measured: the become-a-jeeber column needs 704pt at 320pt wide / 200% text against a ~600pt tab body — it overflows by 104pt, and the child that falls off the bottom is the `FilledButton`. A non-jeeber on a small phone with large text is invited to become a jeeber and given no way to accept, with nothing to scroll to reach the button. The 80pt icon never shrinks to give the space back.

## F30

JeeberTabEmptyState: That 320pt clip is ENGLISH-ONLY, so an Arabic-first spot check misses it. Arabic needs 576pt in the same box and fits. Arabic is shorter than English in every cell I measured (390pt/100%: 328 vs 360; 390pt/200%: 504 vs 568; 320pt/200%: 576 vs 704), so English is the harder locale for this widget throughout.

## F31

JeeberTabEmptyState: The `title`/`subtitle` override params are dead in production (the shell only builds `.dashboard()` / `.earnings()`) and cannot survive 200% text on an ORDINARY phone body — no narrow device required. Driving them with real ARB copy: `kycStatusResubmitTitle/Body` needs 872pt at 390pt wide / 200% (overflows a 680pt body by 192pt), `kycStatusPendingTitle/Body` needs 952pt (overflows by 272pt). The next caller to use these overrides ships an overflow unless the scroll view lands first.

## F32

JeeberTabEmptyState: One break is visible at 100% text, with the system font untouched: `kycStatusPendingTitle/Body` in a 420pt body overflows by 20pt in English (Arabic needs exactly 420pt and fits to the pixel). Every other break here needs the 200% pane, so a reviewer skimming only the default rendering would call the widget healthy.

## F33

JeeberTabEmptyState: The Dashboard and Earnings tabs are indistinguishable to a screen reader user only by id, not by copy — both render the identical `becomeJeeberCard*` triple, so the two states differ ONLY by `Icons.two_wheeler_outlined` vs `Icons.payments_outlined` and by the screen-level Semantics id. The widget's doc calls the shared funnel deliberate, so this is flagged rather than claimed as a defect, but it means a copy-pasted `identifier` would make QA's two Maestro/ui-tree flows indistinguishable while looking perfect on screen. The render test now asserts each preview carries its own id and icon, because `expectedText` provably cannot tell these two apart.

