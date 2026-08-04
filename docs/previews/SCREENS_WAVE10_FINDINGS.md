# Screens wave 10 — findings

`NoOfferTimeoutScreen`, `NotificationPrefsScreen`, `NotificationsListScreen`,
`OfferSubmissionScreen`, `OnboardingScreen`, `OrderHistoryScreen`,
`OrderSummaryScreen`. 7/7 written, 49 previews, 0 agent failures.

43 findings. Nothing here was fixed — this is a record, per the campaign rule
that previews observe production and never edit it.

Pixel figures in this wave were measured with the real Inter face loaded
(`loadInterTestFont` + `withGoldenTestFonts`), not `flutter_test`'s 1-em
square face. See FINDINGS_TRIAGE.md §6 for why that distinction matters.

## NoOfferTimeoutScreen

1. `waiting_countdown` and `waiting_notified_count` are NOT always present,
   contrary to the comments that say they are. no_offer_timeout_screen.dart:440
   and :457 both assert "The node is ALWAYS present (Maestro flows resolve
   it)", but that is only true inside `_BroadcastHeader`. `_WaitingLoaded`
   (line 350) swaps the whole header for `_NoOffersYetHeader` once
   `state.isNoOffersYet`, so both ids vanish from the tree exactly when the
   customer has waited longest — and any Maestro flow that resolves
   `waiting_countdown` after the window elapses will fail to find it. Pinned by
   the `an elapsed window with zero offers IS no-coverage` case in the render
   test (both ids assert `findsNothing`). The same erasure happens in the error
   and terminal bodies. Beyond the flow breakage it is a UX loss: the no-
   coverage block is the one state with no elapsed-time signal at all.

2. The error body removes the free pre-accept Cancel (D69).
   `_WaitingView._body` returns `_WaitingError` INSTEAD of `_WaitingLoaded`
   (line 183 / class at :210), so a customer whose status read failed on a
   network blip is left with Retry and the app-bar back arrow only — no
   `waiting_cancel_cta`, no `waiting_retarget_cta`. Cancelling pre-accept is
   supposed to be free and always available; a transport failure on a read
   silently withdraws it. Pinned by the `the network failure blames the
   connection` case.

3. The contract-violation state offers a Retry that is documented to be
   useless, and it loops. `_WaitingError` always builds `OmdsErrorState(...,
   onRetry: onRetry)` (line 230) with no branch on `failure`, while
   `WaitingCubit._failContract` exists precisely because "retrying re-reads the
   same broken payload" and tears the streams down. `retry()` emits `const
   WaitingState()` and re-runs `load()`, which hits the same 200-with-bad-
   payload and re-enters `_failContract` — an infinite, read-spending dead end
   on the one screen state where the client already knows the action cannot
   help. The distinct copy is correct; the distinct affordance is missing.

4. `_RequestSummaryCard` (line 482) renders the customer's own description with
   no `maxLines` and no cap (line 511). The `Longest content · compact 320`
   preview shows what that costs: a realistic customer-typed paragraph fills
   the 320x568 viewport on its own and pushes `waiting_review_offers_cta`,
   `waiting_retarget_cta` and `waiting_cancel_cta` entirely below the fold.
   Nothing above the card hints there is anything below it, so on the narrowest
   supported phone a verbose request hides every action the screen offers.

## NotificationPrefsScreen

1. A designed confirmation dialog exists in three translated ARB keys and zero
   code. `notificationPreferencesDisableOffersTitle` ("Stop offer
   notifications?"), `...Body` and `...Confirm` ("Turn off") ship in app_en.arb
   + app_ar.arb with generated getters, and the ARB itself describes them as
   "the confirmation dialog shown when the user turns the offers toggle off".
   Nothing under lib/ reads any of them: `_CategoryRow` for offers is wired
   straight to `cubit.toggleCategory`, so offers goes off in one unguarded tap
   exactly like marketing. Pinned by the render test (`turning offers OFF shows
   no confirmation, only the flip`).

2. `_ErrorView` discards the failure classification the cubit computes.
   `NotificationPrefsCubit._view` maps the repository failure onto
   `NotificationPrefsFailureView` and `NotificationPrefsError` carries it, but
   `_ErrorView` renders `l10n.notificationPrefsLoadError` unconditionally —
   `network` and `unknown` are byte-identical on screen. An offline user is
   told "Couldn't load your notification preferences." with no connection hint
   and offered a Retry that will fail the same way.

3. `NotificationPrefsLoaded.isSaving` is emitted and never rendered. The cubit
   sets it before every debounced PATCH; the identifier does not appear
   anywhere in notification_prefs_screen.dart. The row stays enabled and
   unmarked for the 500 ms debounce plus the round trip, so the ONLY feedback a
   save ever produces is the failure snackbar — a successful save is silent and
   indistinguishable from not having saved.

4. `_ErrorView` has no horizontal padding and no scroll view, unlike every
   other surface on the screen. It is a bare `Center` > `Column` while
   `_PrefsBody` uses `EdgeInsetsDirectional.symmetric(horizontal:
   Spacing.medium)`. Measured with the real Inter face: at 100% on 390 pt the
   failure line is 298 pt and the gap is invisible, but at 200% on a 320 pt
   device it wraps to three lines running from x=0 to x=320 — flush against
   both screen borders. It does not overflow and Retry stays reachable, so this
   is polish, not breakage; but the error body cannot scroll, so there is no
   headroom if the copy grows.

5. At the accessibility ceiling the locked transactional row is not built at
   all. On 320x568 at 200% the loaded `ListView` carries 814 pt of scroll
   behind a 512 pt viewport (real fonts) and stops building past viewport +
   cache extent: four of five rows exist on arrival and
   `notif_prefs_transactional_lock_icon` — the id JM-058 AC2 and the on-device
   jm-058 flow both assert — is absent from the widget tree AND the semantics
   tree until the user scrolls. NB the 1618 pt figure recorded in the wrapper
   screen's preview section was measured under flutter_test's 1-em face; the
   real extent is about half that, and the conclusion is unchanged because the
   locked row is last.

6. `_onBack`'s `goNamed('customer-profile')` fallback is unreachable, and the
   class dartdoc ("Back -> `customer-profile`") documents the branch that never
   runs. `settings-notifications` is declared as a CHILD of `/settings` in
   app_router.dart and go_router materializes a page for every matched ancestor
   with a builder, so `canPop()` is true on every route into this screen and
   the arrow always pops to LiveSettingsScreen. Were the fallback live it would
   also disagree with the router's own `AppRouter.backFallbacks['settings-
   notifications'] == '/settings'`, which is what the SYSTEM back gesture uses.

7. `_onBack` calls `context.canPop()` — a GoRouter extension that throws when
   no `Router` is in scope — and does so outside `build`. The screen therefore
   paints perfectly with no router above it and dies on the first tap of the
   app-bar arrow. Any host that mounts `NotificationPrefsScreen` bare (a
   catalog state, a preview, a widget test) looks correct and is dead to the
   touch; the previews had to seed a real GoRouter to make the affordance
   honest.

8. `_PrefsBody` renders the whole Security section behind `if
   (prefs.transactionalLocked)` while `DioNotificationPrefsRepository._parse`
   hardcodes `transactionalLocked: true` on BOTH parse paths
   (dio_notification_prefs_repository.dart:82 and :94). The branch is dead in
   production and nothing but the fixture exercises it — and if the gateway
   ever produced false, the screen would keep 'working' while
   `notif_prefs_transactional_lock_icon` vanished from the semantics tree and
   the JM-058 acceptance test went red.

## NotificationsListScreen

1. No clock seam on the list: `NotificationRow` exposes an injectable `now:`
   for its relative timestamp and `_LoadedList`
   (notifications_list_screen.dart:184) never passes one, so every row's age is
   measured against the device wall clock. Two consequences the previews made
   visible: (a) no mocked surface can freeze a row's age — the Screen Catalog's
   `Populated` state carried literal `2026-07-05T10:00:00Z` instants that
   render '28d ago' today and grow every day, which is why the extracted
   fixtures now express each row as an OFFSET from the read; (b)
   `NotificationsL10n.relativeTime` returns 'Just now' for any negative
   difference, so a device whose clock is behind the server prints 'Just now'
   on the entire inbox with nothing to distinguish a 3-day-old row.

2. A failed pull-to-refresh is completely invisible. The `BlocBuilder` switches
   on `state.status` alone (line ~108); `NotificationsListCubit.refresh()` on
   failure emits `copyWith(error: …)` with the status still `loaded`, and
   `state.error` is read ONLY inside the `failed` branch via `_errorCopy`. So
   the rows do not change, no banner appears, and the user cannot tell a
   refresh that failed from one that returned the same rows.
   `NotificationsListCubit.acknowledgeError()` — which exists for exactly this
   one-shot banner — has no caller anywhere in the screen. This state is also
   un-previewable: the screen has only a `repository:` seam, no cubit seam, so
   a 'cold load OK then refresh fails' fixture cannot be staged without a
   production change (not made).

3. `_errorCopy` collapses `NotificationsFailure.unauthorized` into the generic
   `loadError` alongside `unknown`/null, so an expired session renders a page
   pixel-identical to an unclassified failure: 'Could not load notifications.'
   over a Retry that re-issues the same unauthenticated read and can never
   succeed, with nothing on the surface telling the user to sign in again. Two
   previews (`Load failed · network` / `Load failed · session expired`) sit
   next to each other precisely because that collapse is invisible from one
   card.

4. `_EmptyBody` positions the empty illustration with `SizedBox(height:
   MediaQuery.of(context).size.height * 0.18)` — 18% of the WINDOW, not of the
   list viewport it is actually laid out in. Any host that gives the list less
   than the full window (an Android multi-window split, the 320x568 compact
   frame, an embedded card) offsets the illustration by the wrong amount. This
   is why the preview frame has to override `MediaQuery.size` and not just wrap
   the screen in a `SizedBox`.

5. The empty state doubles as the failure mode of DI misconfiguration:
   `_resolveRepository()` falls back to `const EmptyNotificationsRepository()`
   when `sl<NotificationsRepository>()` is not registered, so a mis-wired build
   renders 'You're all caught up' — an affirmative claim about server data with
   no read behind it — instead of an error. The `Empty · nothing yet` preview
   is byte-identical to that broken build.

## OfferSubmissionScreen

1. `_displayRef` (offer_submission_screen.dart:320) leaves half of the
   sprint-009 §T5 leak open: `if (id.toUpperCase().startsWith('ORD')) return
   id.toUpperCase();` returns the reference VERBATIM, so a request id of
   `ORD-9C37B6AF-4E21-4E4A-9C1B-1F2A3B4C5D6E` is rendered in full in the
   composer heading — the exact raw string the audit graded an F. Only ids that
   do NOT already start with `ORD` reach the shortening branch. The
   `offerSubmissionScreenOpaqueOrderRef` /
   `offerSubmissionScreenCompactCeiling` pair shows both halves side by side,
   and `_OrderRefHeader` sets no `maxLines`/`overflow`, so the full reference
   wraps across the heading at 320 pt.

2. The JM-045 economics layer — the reason this screen exists — is unreachable
   from any dev surface, and was already unreachable from the Screen Catalog.
   `_price` is derived only from `_priceController.onChanged`, and both the
   price and the note live in `TextEditingController`s owned by the private
   `_OfferComposerState` with no ctor seam, so every statically-buildable state
   renders `feeLinePending` / `netLinePending` / `reserveNotePending` and the
   wallet currency never appears at all (asserted: `find.textContaining('USD')`
   finds nothing on the idle composer even though the wallet fixture answers
   25.00 USD). Missing seam: an `initialPrice`/draft parameter on
   `OfferSubmissionScreen`, or rendering the money lines off `OfferFormState`
   rather than the controller. Not added — no production edit was in scope.

3. The inline validation errors are hardcoded English and bypass localization
   entirely. `OfferFormCubit._validatePrice` / `_validateEta` emit 'Price must
   be greater than 0' / 'ETA must be greater than 0' and the view pipes them
   straight into `errorText`, so an Arabic composer shows two English field
   errors under Arabic labels. This is the same defect JEBV4-246 fixed for the
   error SNACK (by moving to `errorReason` + `OfferComposerL10n`) and did not
   reach the field errors. Pinned by the AR case in the specifics group.

4. `OfferComposerL10n.title` (`offerSubmissionTitle`, 'Send your offer') labels
   two different things on one screen: it is the `OMDSAppBar` title AND the
   `OMDSSectionCard` header over the economics block (`_EconomicsCard`, line
   608). The card that explains the 10% reserve therefore has no title of its
   own, and the same three words are rendered twice — asserted as
   `findsNWidgets(2)`.

5. Three of the six `OfferFormMode`s have no visible still frame at all.
   `success`, `requestGone` and `error` live only in the `BlocConsumer`
   listener, and `error` shows a transient snack then immediately calls
   `acknowledgeError()` — so a jeeber who looks away during a failed send
   returns to a composer pixel-identical to idle, with no record that the send
   failed. That includes `offerCapReached`, the 20-live-offer throttle, which
   is the one failure with an actionable next step ('withdraw one to submit a
   new offer') and no persistent surface to say it on.

6. The composer stays fully editable while a submit is in flight and offers no
   way to cancel: `offerSubmissionScreenSubmitting` shows the price field, the
   ETA dropdown and the note field all still mounted and interactive behind a
   spinner-only CTA, and `OfferFormCubit.submit` has no timeout — a POST that
   never answers parks the screen in that state indefinitely.

## OnboardingScreen

1. The slide copy does not fit its box and the box cannot grow.
   OmdsWalkthroughSwitcher hard-codes SizedBox(height: 170) around
   OmdsWalkthroughStep, whose Column is mainAxisSize.min with no maxLines, no
   ellipsis and nothing scrollable, so copy that stops fitting is painted
   outside and clipped — silently in release. Measured with the real Inter
   faces + the deterministic Noto Arabic subset (body overflow, px): 390x844
   slide1 ok/ok/118 EN 200%/31 AR 200%; slide2 ok/ok/166/75; slide3
   ok/ok/118/75. 320x568 slide1 ok/ok/166/124; slide2 42 EN at DEFAULT text
   size/ok/258/77; slide3 ok/ok/166/126. So the app's first screen already
   loses the last line of slide 2 in English on the narrowest supported phone
   at 100% text, and loses copy on every slide in both locales at 200%.
   _BottomPanel's own Column and the 200pt illustration never overflow — the
   whole failure is the fixed copy box. Arabic survives 100%/320 only because
   it says the same thing in fewer glyphs: a copy-length margin, not a layout
   one.

2. The documented illustration fallback is unreachable from anywhere.
   _IllustrationArtwork degrades to the tinted _OnboardingPage.icon glyph when
   asset is null and _WalkthroughIllustration's doc calls that the resilient
   path, but _onboardingPages hard-codes all three SVG asset paths and takes no
   injection — no dev surface and no test can render it. The only observable
   degraded state is the blank SizedBox.square from placeholderBuilder while
   the SVG decodes.

3. There is no seam for the carousel position. OnboardingScreen builds `final
   _pageController = PageController()` in a field and exposes no initialPage /
   controller parameter, so slides 2 and 3 are reachable only by walking the
   element tree for the PageView and jumping its public controller after the
   first frame (what OnboardingScreenPreviewHost(slide:) does). Two of the
   three designed slides — including the only one with the Get Started CTA and
   the only one carrying a past wrap bug — were therefore invisible to every
   dev surface until now; the Screen Catalog had never shown anything but slide
   1.

4. Skip and Get Started WRITE before they navigate: _completeAndNavigate awaits
   OnboardingCubit.complete(), which persists app.onboarding.completed. The
   Screen Catalog entry drove that over the device's real SharedPreferences, so
   one tap while browsing the catalog permanently suppressed the real first-
   launch walkthrough, and tapping the العربية chip (LocaleCubit.setLocale,
   also persisting) changed the whole app's language on the next cold start.
   Fixed in the extraction by moving both cubits onto in-memory prefs — no
   production change.

5. The catalog's two locale states were not deterministic and did not do what
   their labels said. Both were built over the device's real prefs, and
   LocaleCubit._resolveInitial reads the persisted app.locale.languageCode
   BEFORE deviceLocaleProvider — so on any device where a language had ever
   been chosen, the entry's `locale:` argument was ignored and 'Slides — EN'
   and 'Slides — AR' rendered the same chip. The extracted fixtures seed the
   persisted key, so the fixture decides.

6. The language chip is live in the canvas but only half-connected there:
   tapping it drives LocaleCubit.setLocale, which flips the chip, while the
   card's copy keeps coming from the preview's own `localizations:`. In the
   shipped app app.dart binds MaterialApp.locale to the same cubit so the two
   cannot disagree; any dev surface that pins the cubit without pinning the app
   locale always can. LocaleCubit.resetToDeviceLocale() still has no caller
   anywhere, so a chosen language is one-way.

## OrderHistoryScreen

1. Filter chip loses its gutter above 1.5x text: `_FilterBar`'s `usesLargeText`
   branch sets the row's horizontal padding to ZERO on both sides. Measured on
   a 390 pt frame through real Inter/Noto faces — the chip sits 16.0 dp off
   each edge at 1x and 0.0 dp at 200% (flush against the RIGHT edge in AR),
   while every card below it keeps its 16 dp inset. The same branch also
   changes its silhouette: `Expanded` full-bleed at 358.0 dp at 1x vs shrink-
   wrapped 238.9 dp inside the SingleChildScrollView at 200%. One control, two
   shapes, misaligned with the list exactly for the users who turned large text
   on. lib/features/order_history/presentation/order_history_screen.dart:152
   (_FilterBar)

2. EN tab labels clip at 200% and AR does not, so an AR-only review misses it:
   `Tab` lays its label out with `softWrap: false` + `TextOverflow.fade` and
   this TabBar is not scrollable, so "Completed" fades mid-word — it wants
   147.0 dp of the 98.0 dp third of the bar it is given. The Arabic label wants
   85.5 and gets 85.5. There is no `isScrollable` fallback.
   lib/features/order_history/presentation/order_history_screen.dart:93

3. The error branch is the ONLY body on this screen with no scroll view and no
   pull-to-refresh. The empty branch is wrapped in `OmdsPullToRefresh →
   ListView`; the error branch is returned bare into the TabBarView, so the
   "Try again" button — the sole recovery affordance, since the pull gesture is
   absent here — cannot be brought back into view if the tab body is ever
   shorter than the content. Measured: icon-top to button-bottom is 214.0 dp at
   1x and 388.0 dp at 200% (296.5 AR) inside a 486 dp body, so it needs ~428 dp
   of tab area once OmdsErrorState's 20 dp padding is added. Structural gap
   rather than a live clip at review sizes.
   lib/features/order_history/presentation/order_history_screen.dart:270

4. STALE CLAIM in a neighbouring preview section: `ordersTabErrorNetwork` in
   lib/features/shell/tabs/orders_tab.dart:316-337 documents this same error
   branch as overflowing — "at 1.6× the button's bottom sits 27 pt past the
   viewport; at 2.0× the whole button starts 134 pt BELOW it". Re-measured with
   the real Inter + Noto Arabic faces loaded, it does not overflow at ANY scale
   in a 390-wide frame (at 200% the button clears the bottom by 51 dp, in both
   locales). Those numbers were taken under Flutter's 1-em test face, where the
   wrapped message measures roughly twice as tall as on a device.

5. The Completed and Cancelled tabs are unreachable from any external seam, so
   two of the three per-tab empty subtitles (`orderHistoryEmptyCompleted` /
   `orderHistoryEmptyCancelled`) have NO dev surface at all — not in the
   canvas, not in the Screen Catalog. `_tabController` is constructed at index
   0 and is only ever driven by `_onTabChanged` (a user tap); it never reads
   `state.activeTab`. The binding is one-way: `OrderHistoryCubit.selectTab` is
   public and moves `state.activeTab` — which is what `state.currentTab` in the
   transient-error snackbar listener reads — without moving the TabController,
   so a cubit-side tab switch would show one tab and report errors for another.

## OrderSummaryScreen

1. All three typed failures are one indistinguishable card.
   `OrderSummaryFailure` classifies network/notFound/unknown and
   `OrderSummaryCubit` stores it in `state.error`, but `_OrderSummaryView`'s
   `failed` arm never reads it — it hardcodes `l10n.errorGeneric` ('Something
   went wrong. Please try again.'). The render test pins the two error previews
   as byte-identical text lists: a deleted order and an offline phone produce
   the same screen, and neither names its failure or advises the user.

2. Retry gives zero feedback and cannot help a 404. `OmdsErrorState.onRetry`
   calls `OrderSummaryCubit.refresh()`, which — unlike `load()` — never emits
   `loading`; on a second failure it emits `copyWith(error: …)` with the status
   still `failed`, i.e. the frame already on screen. Pinned: tap Retry, pump
   one frame, no `OmdsLoadingState` ever appears and the screen text is
   identical before and after.

3. A misconfigured build shows a FABRICATED order as authoritative.
   `OrderSummaryScreen._resolveRepository()` ends in `return
   FakeOrderSummaryRepository()` when GetIt has no `OrderSummaryRepository`
   bound, and that fake answers ANY delivery id with a canned order (Kamal Hajj
   · 9.00 USD · 20 min · 'Groceries from Spinneys'). The `Unconfigured DI`
   preview passes no repository at all and renders a complete, unmarked card —
   no badge, no banner, no error — telling the customer to hand over a cash
   amount that is fiction. Guardrail §6.4 keeps the fake out of DI; this line
   puts it back in the widget tree.

4. `0.00 USD` is presented as a price rather than as a missing one.
   `DioOrderSummaryRepository` null-coalesces `price` to `0.0` and `currency`
   to `'USD'` independently, so a thin delivery row renders an authoritative
   zero in a currency nobody chose, directly above 'Pay cash on delivery'. The
   ETA and tier cells beside it both have an honest 'Pending' placeholder for
   the same payload; the price pill has none. Pinned in `Minimal payload`
   (`order_summary_price` reads 'Price|0.00 USD').

5. A uuid can stand where the jeeber's name goes. `jeeberName: … ?? (jeeberId
   ?? '')` in the same parser, and all three enrichment reads that could supply
   a name (`/v1/requests/:id`, `/v1/offers`, `/v1/users/:id`) are swallowed by
   design — so the customer is told they are meeting
   `jbr-7f3c1a92-4d8e-4b21-9a05-6c1e2f3a4b5d`, with `J` in the avatar.

6. Nothing on the loaded screen says WHICH order it is. `OrderSummary` carries
   `deliveryId`, `requestId` and `conversationId`; the screen renders none of
   them and there is no timestamp or status either, so two accepted orders with
   the same jeeber and price are the same picture — on the screen JM-056 exists
   to deep-link INTO from a transaction row. Pinned as a negative assertion on
   DEL-2044/REQ-2044/CONV-2044.

7. Only the loaded state is machine-addressable. `order_summary_root` wraps
   everything and every other identifier (`order_summary_price`, `_eta`,
   `_tier`, `_cash_label`, both CTAs) lives inside `OrderSummaryPinned`. The
   `loading` and `failed` arms carry no identifier of their own, so a Maestro
   run — and the D30 assertions in 63_W1_TEST_PLAN — cannot distinguish 'still
   loading' from 'failed' from 'mounted but empty': all three are an empty
   `order_summary_root`.

8. A loaded summary can never be refreshed. `OrderSummaryCubit.refresh()` is
   documented as 'pull-to-refresh', but `_Loaded` is a bare `ListView` with no
   `RefreshIndicator` and no action anywhere, so its only caller is the error
   state's Retry. Once the card is on screen its ETA and tier are frozen until
   the customer leaves the route and returns.

9. The price pill has no width ceiling and overflows the header row.
   `_PriceBlock` is a rigid `Row` child with no `maxLines` and no `Flexible`,
   so it starves the `Expanded` name beside it. Measured on this screen through
   the REAL Inter/Noto faces (never the 1-em test face): with a 7-digit SYP
   amount at 390 pt it is clean to a text scale of 1.5, overflows by 4.1 px at
   1.8 and by 30 px at 2.0 — the same 30 px in Arabic; and on the 320 pt
   compact frame even the ORDINARY 14.50 USD card overflows by 4.7 px at 2.0.
   The sibling rendering of the same JM-031 contract
   (`OrderSummaryPinnedHeader` in live_tracking) already fixed this by making
   its price `Flexible` with `maxLines: 1`. Deliberately NOT asserted in the
   test — pinning the broken measurement would turn the fix into a failure.
