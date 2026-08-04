# W5 — dev-chat-preview

**Status: `no-change-needed`. Zero files changed.**

## One-line justification

`dev_chat_preview_screen.dart` contains no UI of its own — it is a selector→config switch that
constructs the **already-redesigned** `ChatScreen`, so it inherits the design system in full and has
nothing left to re-skin.

## Scope

| File | Verdict |
| --- | --- |
| `lib/features/chat/presentation/dev_chat_preview_screen.dart` | no change |

## Evidence

**1. The file has no styling primitives at all.** A grep for
`Color(` · `Colors.` · `TextStyle` · `EdgeInsets` · `BorderRadius` · `Padding` · `Scaffold` ·
`AppBar` · `Semantics` over all 149 lines returns **nothing**. There is no hardcoded hex to
tokenise, no bespoke card to swap for `JeebOutlinedCard`, no gutter or block rhythm to correct, no
`Semantics(identifier:)` to preserve. The whole file is two `build` methods, each of which returns a
single `ChatScreen(...)` with fixture arguments.

**2. Everything it renders is already on the system.** `ChatScreen` is redesigned (it builds
`JeebTopBarAction`, and the redesign markers are present in `chat_screen.dart`,
`chat_app_bar.dart`, `chat_message_bubble.dart` and `order_chat_pinned_summary.dart`). The only two
visual surfaces the preview *configures* rather than inherits — `ChatFeeBanner` (via `feeNotice`)
and `ConfirmDeliveryActionSheet` (via the auto-open in `_DeliveryManPreviewState.initState`) — are
OMDS/theme-driven with no hardcoded hex, so they pick up the Wave 0 palette automatically. Both are
production widgets outside this lane's assigned file.

**3. Restyling here would actively violate the wave's rules.** The only way to put design-system
code in this file is to stop delegating to `ChatScreen` and hand-roll chat UI locally — which is
exactly the "never hand-roll a copy" prohibition, and would introduce a second visual language for
the same screen. The file's value is that it renders *the real screen*; any divergence makes it a
worse harness.

**4. It is a dev-only capture harness, not a user surface.** Reached only through the
`JEEB_DEV_CHAT` router seam and the devtool catalog (`batch_02_entries.dart`, 7 entries) — never in
release. Its consumers are deterministic Figma-frame capture and two widget tests
(`dev_chat_sending_fixture_test.dart`, `dev_seam_route_pin_test.dart`), which assert
`find.byType(DevChatPreviewScreen)` and fixture content. Churn here buys no user-visible pixel and
risks the capture determinism the file exists to provide.

## Neighbour comparison (`21-order-chat.png`)

Re-viewed after the assessment. Every band in the render — the avatar + rating + call-affordance top
bar, the navy pinned order strip with its white `Track` pill, the grey inbound / navy outbound
bubbles, the pill system chips, the orange-outlined ETA note, the outlined quick-reply row, and the
grey composer with its navy mic circle — is produced by `ChatScreen` and its child widgets. Loading
`/dev-chat?selector=accepted` renders that same tree; the preview file's contribution is limited to
which fixture gateway and which counterpart name get passed in.

## Deferred / not touched

- `chat_fee_banner.dart` and `confirm_delivery_action_sheet.dart` still style through
  `theme.textTheme.*` and `colorScheme.*` rather than `context.jeebText` / `context.jeebRoles`.
  They are theme-correct today (no literals), and they are production widgets outside this lane's
  assigned file — flagged for whoever owns the chat-widgets lane, not changed here.
- Fixture display strings (`'ORD-23748'`, `'Kamal Hajj'`, `'Sami Fawaz'`) are hardcoded. They are
  dev fixture data, equivalent to test data, and changing them would be a copy change — out of scope
  for a re-skin.

## Verification

No code changed, so the baseline is untouched by construction: analyze 0 errors, `flutter test`
4664 pass / 61 skip / 1 pre-existing fail (`gesture_log_test`, local-SDK skew).
