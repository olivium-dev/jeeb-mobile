# Screens wave 02 (wallet, deep_link_targets) — defects

7/7 written, 51 previews.

## F01

CustomerWalletStubScreen: No bottom SafeArea: `app_router.dart` mounts the screen as a bare top-level GoRoute (no ShellRoute, no SafeArea) and `Scaffold` does not SafeArea its body, so the scroll viewport ends at the physical bottom edge of the display (measured: viewport bottom == display bottom in every window). Scrolled to the end, the `Got it` CTA rests on the ListView's own `Spacing.xLarge` = 24 pt bottom padding, against a 34 pt home indicator — the last 10 pt of the dismiss button sits under the system gesture bar. Font-independent (24 < 34); pinned by the `the body runs under the home indicator` test and reproduced in Arabic.

## F02

CustomerWalletStubScreen: The screen's only action is inside the scroll body rather than pinned to the Scaffold. On a 390x844 phone at 100% nothing scrolls at all (maxScrollExtent 0), which is why this went unnoticed; at 200% text the same phone has 1210 pt of scroll and a 320x568 phone has 1202 pt, so the CTA arrives entirely below the fold with no affordance indicating the screen scrolls. The app-bar back button is the only visible way out.

## F03

CustomerWalletStubScreen: `customer_wallet_stub_done` — the id this screen's own dartdoc publishes as the QA target — is absent from the widget tree AND from the semantics tree on arrival at 320x568, and at 200% text on any phone: a `ListView` stops building past viewport + cache extent. An id-based UI driver or a screen reader querying it finds nothing until the user scrolls. Asserted for all three windows in `below the fold the CTA is not built, and not in semantics`.

## F04

CustomerWalletStubScreen: Both exits (`OMDSAppBar.onBackPressed` and the CTA `onTap`) call `context.canPop()`, i.e. `GoRouter.of(context).canPop()`, which throws with no GoRouter in scope. The screen BUILDS fine without one — neither call happens during `build` — so any host that is not the app router (preview canvas, Screen Catalog, a bare widget test) looks correct right up until someone taps. The fixture host therefore has to supply a real GoRouter; the screen itself has no non-router fallback.

## F05

CustomerWalletStubScreen: Margin on a small phone is thin: at 320x568 and default text the content is roughly 460 pt of a 512 pt viewport with real font metrics (the 200 pt overflow measured under `flutter_test`'s square-glyph font is inflated). One reworded sentence in either paragraph pushes the default-text-size case over the fold on the smallest supported device.

## F06

TransactionDetailScreen: _DetailRow gives its VALUE no width constraint — only the label is Expanded, so the value Text is laid out first against an unbounded main-axis constraint and can neither wrap nor ellipsize. At the screen's real 390pt width an ordinary `off-`+GUID reference (40 chars, the shape a .NET gateway returns) starves the label to zero and overflows the row by 318pt. It is invisible to `test/features/wallet/transaction_detail_screen_test.dart` only because flutter_test's default 800pt surface is wider than any phone; pinned at 390 in the new test's 'Reserve · GUID reference' group.

## F07

TransactionDetailScreen: Both outbound edges are gated on DATA (`hasOrderLink`/`hasDisputeLink`), not on the row's type, so a refund carrying an `orderId` renders `txn_detail_order_link` AND `txn_detail_dispute_link`. This contradicts the screen's own class doc ('shown for reserve / fee_won / released rows with an order') and the existing assertion `expect(find.bySemanticsIdentifier('txn_detail_order_link'), findsNothing)` in the refund widget test — which passes only because its fixture omits `orderId`, while the SHIPPED `StubWalletTransactionRepository` refund branch sets one. The catalog state named 'Refund — dispute link' has therefore been showing two links.

## F08

TransactionDetailScreen: `WalletTransaction.title` is never read by the screen. Its own doc calls it the fallback 'when no localized copy exists for an unknown row', but `_LoadedBody` derives every string from `txn.type`, so a `WalletLedgerType.unknown` row — where every future W3m type lands — drops the server-supplied label and shows the generic 'Transaction' heading over the generic `txnDetailBody` paragraph.

## F09

TransactionDetailScreen: `_errorCopy` folds `unauthorized` into the same generic 'We couldn't load this transaction. Please try again.' message as `network`/`unknown`, and the only affordance in that state is Retry. A Jeeber whose session expired is told to retry into the same 401 indefinitely; there is no re-auth path off this screen.

## F10

TransactionDetailScreen: The `loaded`-with-null-`transaction` branch of `_TransactionDetailView` (which renders `loadErrorGeneric`) is unreachable: `TransactionDetailCubit` only ever emits `loaded` together with a row, and there is no `cubit:` seam to seed the pair. It is dead defensive code that cannot be previewed or tested through the repository seam.

## F11

TransactionDetailScreen: `_fmtDate` converts the server instant with `toLocal()`, so the rendered date depends on the host machine's timezone. Harmless in production but it means no preview or render test can pin the date text — every state that shows a Date row is machine-dependent.

## F12

WalletActivityListScreen: Large text breaks the ORDINARY ledger, not just a pathological one. The shared three-row fixture (widest amount `+50.00 USD`, short refs) throws `A RenderFlex overflowed by 3.0 pixels on the right` at 200% text on the 390x844 box the previews declare, and already breaks at 150% on a 320x568 device (45 px and 73 px on two rows at 200%). Cause is in `WalletActivityRow`: the signed amount is the one child of the Row outside the `Expanded`, so it claims its intrinsic width first and the row grows past the viewport instead of the text column yielding. The row's own preview file documents a 59 px break on a pathological ref; what this screen adds is that an everyday page breaks too. Pinned by two KNOWN-defect tests in the render suite (with 100% controls), so a fix will make them fail loudly.

## F13

WalletActivityListScreen: `_WalletActivityView._errorCopy` folds `WalletLedgerFailure.unauthorized` in with `unknown` and `null`, so an expired/revoked session renders the generic "Could not load your activity." and is offered `wallet_activity_retry_cta`, which re-runs the same unauthorized call. There is no sign-in or re-auth affordance anywhere on the surface, so the loop has no exit. `walletActivityListScreenSessionExpired` and `walletActivityListScreenOffline` are pixel-identical apart from one line of copy.

## F14

WalletActivityListScreen: The retry has no in-flight feedback at all. `wallet_activity_retry_cta` calls `WalletLedgerCubit.refresh()`, which emits nothing before awaiting the fetch — the failed surface stays byte-identical while the request is on the wire: no spinner, no disabled button, no snackbar. Offline (instant failure) this is invisible; on a slow connection the CTA looks ignored and invites repeated taps. Related: the retry uses `refresh()` rather than `load()`, so the cold-load `loading`/skeleton state is never re-entered after a failure.

## F15

WalletActivityListScreen: The infinite-scroll footer cannot distinguish "more exists" from "more is loading". `showFooter = loadingMore || loadMoreError || hasMore`, and the `hasMore` branch falls through to the same animating `wallet_activity_load_more` shimmer the in-flight branch renders. A fully settled page-1-of-3 list therefore ends in a skeleton row that shimmers as though a fetch were running, and nothing will actually be fetched until the user scrolls. Reproduced by `walletActivityListScreenPaged`; the render test asserts the rows are up, `loadingMore` is false and the skeleton is showing anyway.

## F16

WalletActivityListScreen: `_LoadedList` builds every `WalletActivityRow` without the widget's own `now` seam, so each relative timestamp is read off `DateTime.now()`. The row has an injectable clock and the screen ignores it, which makes every dev surface of this list (catalog, previews, any future golden) drift with the wall clock — the fixture instants are fixed, so the ages they render keep growing.

## F17

WalletActivityListScreen: `_LoadingSkeletons` takes a `WalletActivityL10n copy` and never reads it — a dead parameter, and a symptom: the D73 loading state renders eight shimmer boxes with no text and no semantics label beyond `wallet_activity_loading`, so a screen-reader user gets nothing at all during the cold load.

## F18

WalletActivityListScreen: `_EmptyBody`'s top spacer is `MediaQuery.of(context).size.height * 0.18` — 18% of the WHOLE screen, not of the body — so the empty state's vertical placement does not track the app bar, the status bar or the safe area. It is visibly off-centre in the nested-Scaffold preview host, and shifts between devices with different chrome heights.

## F19

WalletChargeInfoScreen: Dead navigation branch + wrong contract: both back affordances branch on `context.canPop()`, but that branch never runs in the app. `/wallet/charge-info` is declared FLAT in `app_router.dart` (a top-level GoRoute beside `/wallet`, not a child of it) and all four `+ Top up` CTAs reach it with `goNamed`, which replaces the stack. Verified by driving the real `AppRouter.create` router in a throwaway probe: after `goNamed('wallet-charge-info')` the match list is 1 page, `canPop()` == false, and the back CTA lands on `/wallet` (WalletHubScreen). Consequences: (a) this file's own doc comment — "when pushed from one of those callers it pops back to the caller (canPop)" — describes a path that does not exist; (b) `lib/features/offers/presentation/offer_submission_screen.dart:786-791` pops its sheet first "so a back from charge-info returns to the composer with the draft intact", which it does not — back returns to the wallet hub and the composer/draft context is lost; (c) if any caller ever does push, the CTA labelled "Back to wallet" would silently return to onboarding-funding / kyc-pending / the insufficient-balance composer instead of the wallet.

## F20

WalletChargeInfoScreen: Step badge overflows at large text: `_Step`'s numbered badge is a `Container` fixed at `Sizes.xLarge` (24x24) holding a `Text` that DOES follow the user's text scale. Measured at 200%: the render box is clamped to 24x24 but `RenderParagraph.textSize` is 24x40, so the digit paints 16 pt outside its own circle. `Container(alignment:)` is an `Align` — nothing clips, nothing throws, and `tester.getSize` reports a healthy 24x24, which is why no existing test sees it. At 100% the same digit lays out 20 pt and fits.

## F21

WalletChargeInfoScreen: The only way out is below the fold far earlier than the screen's "static instructional page" framing implies. `charge_info_back_cta` is the last child of a `ListView` with no sticky/pinned treatment. Measured overrun past the viewport: 192 pt on a 320x568 phone at NORMAL text (the CTA is not even built; the page visually ends on the fee note), 1198 pt at 200% text on a 390x844 phone (step 3 is already cut at 888 pt against a 788 pt viewport), 922 pt in Arabic at 200%. On a 390x844 phone at 100% the same content needs no scrolling at all — so whether this screen appears to have a way out depends entirely on the device and text size.

## F22

WalletHubScreen: Balance line overflows a real phone at DEFAULT text size: `Row(Text(_fmt(amount)), SizedBox, Text(currency))` in `_LoadedBody` has no Flexible/Expanded child, so on the 390x844 box the previews declare, an LBP wallet (89750000.00 LBP) overflows the balance Row by 6.5 pt in BOTH en and ar with no accessibility setting touched. Pinned by the render test `the LBP wallet does not fit a 390 pt phone, even at 100% text`.

## F23

WalletHubScreen: The same balance Row overflows by 82 pt at 200% text on the plainest possible wallet (145.00 USD) — i.e. the accessibility ceiling is broken for every jeeber, not just LBP ones; the LBP ceiling is 362 pt over.

## F24

WalletHubScreen: `wallet_gift_badge` (OmdsChip) is a Row inside a Container with nothing flexible either: 51 pt over at 100% text on the LBP fixture, and 276 pt (en) / 173 pt (ar) over at 200% text on the ordinary '50.00 USD starter credit' label. `_StatRow` (reserved-now) is the counter-example — its label is Expanded, so it shrinks instead.

## F25

WalletHubScreen: `_fmt` is `v.toStringAsFixed(2)`: no thousands grouping and no locale-aware numerals anywhere on the screen. An Arabic jeeber sees latin digits and an ungrouped `89750000.00`, with the currency code mirrored to the LEFT of the amount by the RTL Row. There is no NumberFormat on this screen.

## F26

WalletHubScreen: `wallet_topup_cta` renders IDENTICALLY offline — full-strength OmdsPrimaryButton, no disabled state, no banner, no inline notice. The D35 guard lives inside `_onTopUp` and only speaks AFTER the tap, as a SnackBar that auto-dismisses in 4 s; the screen then looks exactly as it did before the tap. Asserted in `offline: the top-up CTA looks live and blocks only on tap`.

## F27

WalletHubScreen: The `failed` branch replaces the ENTIRE body, so a jeeber whose balance failed to load also loses `wallet_topup_cta` — the one action that would fix an empty wallet — plus `wallet_how_fees_work`, `wallet_earnings_row` and `wallet_see_all_activity`. Only `Retry` survives. Asserted in `the error preview loses the whole body, top-up included`.

## F28

WalletHubScreen: The `loading` branch offers no action at all (no top-up, no retry, no skeleton), and `WalletHubCubit.load()` guards on `status != initial`, so a read that never lands strands the screen on the spinner permanently with no way out — strictly worse than the error state, which at least offers Retry. Asserted in `the loading state offers no action at all`.

## F29

WalletHubScreen: A failed pull-to-refresh is INVISIBLE: `WalletHubCubit.refresh()` catches the failure and emits `copyWith(error: ...)` while leaving `status: loaded`, and the loaded body never reads `state.error`. The jeeber keeps reading stale balance/reserve numbers with no indication the refresh failed. This is the one state the previews cannot construct (no `cubit:` seam), and it is noted in the section prose.

## F30

ChatDetailScreen: /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile/.claude/worktrees/widget-previews-pilot/lib/features/deep_link_targets/chat_detail_screen.dart:1744 — the client's "Track my order" CTA is DEAD on every deep-link entry into an accepted order-chat. The screen wires a non-null `onTrackOrder`, but `ChatScreen` only renders the CTA when `state.canTrackDelivery` (i.e. `acceptedDeliveryId` is set), and that is seeded ONLY from `initialTrackingDeliveryId`, an in-chat accept result, or a live `PhaseChanged` frame. ChatDetailScreen never passes `initialTrackingDeliveryId`, even though at that point it holds `_deliveryId` and already feeds that same id to `order-summary`, `escalate` and to the tracking route inside the callback itself. Measured on the `Accepted · pinned summary` preview: OfferAcceptedBanner renders (1), dispute affordance renders (1), `onTrackOrder` non-null, `initialTrackingDeliveryId == null`, `find.text('Track my order')` == 0. So a customer arriving from a chat push tap / the In-Progress "Open chat" CTA gets the accepted banner with no way to reach live tracking, while a customer arriving from the accept sheet does. Not fixed — no production edit was in scope.

## F31

ChatDetailScreen: /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile/.claude/worktrees/widget-previews-pilot/lib/features/deep_link_targets/chat_detail_screen.dart:1691 and :1697 — the two states this screen was specifically written to OWN cannot be shown offline at all. `_loading` (centered OmdsLoadingState) and `_resolutionUnavailable` (`_buildResolutionError`, the documented "THIRD STATE" with the retry CTA, the whole point of the ConversationLookup.unavailable work) both live on the async `_resolveAndBuild` path, and the only seam — `debugGateway` — short-circuits AROUND that path by handing the screen an already-resolved conversation. Neither the Screen Catalog nor the preview canvas can render the transport-failure body, so the one surface most likely to regress is the one nobody can look at. Missing seam, deliberately NOT added: a `debugLookup` / `debugResolutionUnavailable` param alongside the existing `debug*` family, honoured before the resolution runs.

## F32

ChatDetailScreen: /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile/.claude/worktrees/widget-previews-pilot/lib/features/deep_link_targets/chat_detail_screen.dart:1405 — the JEEBER leg of this screen has no offline host. `_readRole` reads the ambient `RoleCubit`, and `RoleCubit`'s only constructor requires a real `SharedPreferences` instance (async, plugin-backed), which no preview function and no catalog builder can produce. The "Customer" header fallback (`chatPartyCustomerFallback`), `viewerIsJeeber: true` chrome and the Start-delivery CTA are therefore unreviewable — which is also why the shipped catalog entry has only client states. Missing seam, deliberately NOT added: an optional `UserRole` override on the widget (or a prefs-free RoleCubit seed constructor). The wiring stays covered only by `test/features/deep_link_targets/chat_detail_screen_role_aware_test.dart`, which reaches it through the kDebugMode dev-seam plus mocked SharedPreferences.

## F33

DeliveryDetailScreen: No loading state and no error state exist: while `_statusId` is null the hub fails open to the full legacy list, so a status read STILL IN FLIGHT and a status read that FAILED (500 / transport drop) render a byte-identical surface. The render test asserts both produce exactly the same row set (`_kFailOpenRows`), and neither carries error copy nor a retry — after a failed read the only re-trigger is a `delivery` push or a foreground resume, so a customer can sit on a wrong action list indefinitely with nothing on screen admitting the screen is guessing (lib/features/deep_link_targets/delivery_detail_screen.dart, `_loadStatus` swallows `OrderChatSummaryException`, `_failOpenChildren`).

## F34

DeliveryDetailScreen: The class doc's guarantee — 'Never reached for a known-Delivered order, so Cancel is never shown on a delivered delivery' (`_StatusBucket.unknown`) — does not hold for the FIRST FRAME. `_loadStatus()` is kicked off in `initState` and the first build precedes its completion, so every delivery, a `Done` one included, paints Cancel + Verify OTP + Live tracking before the read lands; on a slow or failing read it keeps painting them. The `Status pending · fails open` preview is that frame, made inspectable.

## F35

DeliveryDetailScreen: The fail-open list is the only surface that offers **Rate and Cancel together** — a pair no real lifecycle state can produce (a delivery is either still cancellable or already rateable, never both). It is a visible symptom that the unknown bucket is a union of legacy rows rather than a designed state.

## F36

DeliveryDetailScreen: `_bucket` folds EVERY non-delivered terminal (`expired`, `disputed`, `rated`, `failedneedsescalation`) into `_StatusBucket.cancelled`, and `_cancelledChildren` hardcodes the cancelled banner. An expired broadcast — and, worse, a DISPUTED delivery with an open case — tells the customer 'Cancelled / This delivery was cancelled.' The `Expired → Cancelled banner` preview pins this: nothing anywhere on the surface says 'expired', so the two outcomes are one screen.

## F37

DeliveryDetailScreen: The screen's DI fallback silently defeated the Screen Catalog. `_resolveSummaryRepository()` reaches for `sl<Dio>()` when `summaryRepository:` is null, and the catalog entry mounted `const DeliveryDetailScreen(deliveryId: 'ORD-4821')` bare on the strength of a now-stale comment ('No repository/GetIt dependency at all'). The catalog only runs inside the app, where DI IS built, so the designer-facing 'Action hub' state was issuing a live `GET /v1/deliveries/ORD-4821` — a GET, which `CatalogNetworkGuard` passes — and rendering whichever bucket that order was in that day. The same hole exists for `ratingRepository:` on the Rate tap. Both seams are now scripted from the shared fixture file.

