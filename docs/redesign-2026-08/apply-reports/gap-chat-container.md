# gap · 21 Order chat — the `/chat/:id` CONTAINER

Branch `feat/redesign-24-migration`. Lane: `lib/features/deep_link_targets/` (+ the four stale
Maestro chat flows). Companion to `apply-reports/21-order-chat.md`, which rebuilt everything under
`lib/features/chat/`.

Status: **applied, with one correction to the lane brief** (below).

---

## What the container actually renders — measured, not assumed

The brief said `chat_detail_screen.dart` has "a zero-line diff and zero kit imports, so opening a
chat on the device still shows the pre-redesign UI". The first half was true; the second half is
only *partly* true, and the difference decides what this lane had to fix.

`ChatDetailScreen` is a resolver, not a chat UI: after resolution it delegates the whole surface to
`ChatScreen` (`:1722`), which the 21 lane rebuilt on the kit (identity `JeebTopBar`, navy pinned
strip + Track pill, `JeebChatBubble`, `JeebChatComposer`, `JeebQuickReplyRow`). So the **resolved
thread on the device is the redesigned one**. Every pixel this file owns itself is in the two states
it renders *before* delegating, and those were both untouched pre-redesign surfaces:

| State | Was | Now |
|---|---|---|
| resolving (`_loading`) | `Scaffold(body: Center(OmdsLoadingState()))` — **no app bar at all**, blank page, no way back, for the duration of up to three sequential gateway reads | `_ChatResolvingView`: the same `ChatAppBar` identity bar the thread will carry + `_ChatThreadSkeleton` (kit `JeebChatBubble` shells on the thread's own 24 gutter) |
| resolution error | `OmdsErrorStatePage` — Ø80 red `error_outline`, `titleLarge` red title, Material `FilledButton.icon` | `ChatResolutionErrorView`: `JeebInfoNote.error` (soft `errorContainer` panel) + navy `JeebCtaButton.primary` retry, under the same `ChatAppBar` |

Both are `/chat/:id`'s own frames, both are what a user on a real (slow, flaky) network sees first,
and both are now in the redesign language. Kit consumed: `JeebChatBubble`, `JeebInfoNote`,
`JeebCtaButton` (+ `ChatAppBar` → `JeebTopBar`, already kit-borne). Nothing hand-rolled, nothing
copied out of `lib/core/widgets/jeeb/`.

## The pulse is load-bearing, not decoration

The first cut of the skeleton was static, and it **broke `chat_detail_active_thread_test`**
("go('/chat/B') … re-registers B"). Root cause, worth recording because it is invisible from the
diff: `OmdsLoadingState`'s `CircularProgressIndicator` kept a frame permanently scheduled while this
screen resolved, so `pumpAndSettle()` in the suites that mount it kept pumping — which is what let
the async conversation lookup land before the assertions ran. A motionless placeholder settles
immediately and those tests observe an unresolved screen. `_ChatThreadSkeleton` therefore carries a
slow `AnimationController` pulse (`UIConstants.animationSlow`, reverse-repeating, 0.45 → 1.0): same
ticker semantics as the widget it replaces, and a skeleton that does not move reads as an empty
thread that finished loading anyway.

## Refusals

* **No composer / pinned-strip placeholder in the resolving frame.** A composer shell you cannot
  type into is a lie, and a navy order strip before the summary read returns would assert an
  accepted order that may not exist.
* **No outgoing (navy) skeleton bubble.** Navy is the board's "you said this". Every placeholder is
  an incoming muted shell.
* **No new strings.** The error copy reuses the existing `chatHistoryError{Title,Message,Retry}`
  family (it is the same statement to the user); the skeleton is `ExcludeSemantics`, so no
  loading announcement was invented and **no wiring request was needed** — this lane asks the
  integrator for nothing.
* **No avatar / reply-latency in the container.** `OrderChatSummary` carries no avatar URL and no
  reply-latency field, so `ChatScreen`'s `counterpartAvatarUrl` stays unfed — `JeebAvatar` renders
  the title initial, which is exactly what the board draws (navy circle, "K"). Not faked.

## Semantics

* `chat_resolution_error` — **byte-identical**, still on the caller's `Semantics` wrapper.
* New: `chat_detail_resolution_retry` on the retry pill (`<screen>_<element>`; the old
  `FilledButton` carried no id, so this is strictly better for Maestro).
* `chat_detail_back_button` is now emitted on the resolving frame too (it comes with `ChatAppBar`).
  Same side effect the 21 lane already called out for the error frame.
* The 43-identifier inventory the brief refers to lives in `lib/features/chat/` — this file emits
  exactly one of them (`chat_resolution_error`), verified unchanged by grep.

## Maestro (in-lane per the brief)

Four flows still asserted `chat_detail_voice_button`, an id that has not existed on any build since
decision **B-04** refused a composer mic. Deleted the assertions and corrected the header comments
that described a mic affordance and the now-deleted `_ComposerField`/`_AttachButton`/`_SendButton`
internals: `02-chat-client.yaml`, `03-chat-after-aproval-client.yaml`,
`04-delivery-screen-chat-delivery-man.yaml`, `07-chat-dm-blank.yaml`. The mic was **not** resurrected
and no id was invented; `test/features/chat/chat_composer_no_mic_b04_test.dart` remains the guard.

## Tests

Updated (the widget type they asserted on no longer exists — same shape, same intent):
`chat_resolution_reconnect_test`, `chat_resolution_self_heal_test`,
`chat_resolution_transport_failure_test` — 13 × `find.byType(OmdsErrorStatePage)` →
`find.byType(ChatResolutionErrorView)`, plus the now-unused `package:omds/omds.dart` import. Every
behavioural assertion (`find.text('Try again')`, retry taps, backoff/pre-empt counters) is untouched
and still passes, because the copy and the retry affordance are unchanged.

## Gates

* `dart analyze lib/features/deep_link_targets test/features/deep_link_targets` → **No issues found**.
* `flutter test test/features/deep_link_targets/ test/features/chat/chat_picker_binding_test.dart
  test/features/chat/chat_poll_cadence_test.dart
  test/core/notifications/push_refresh_topic_routing_test.dart` → **90 passing, 0 failing**.
* `flutter test test/semantics_identifier_surfacing_test.dart test/decision_violations_test.dart`
  → **17 passing, 0 failing**.
* `bash tool/check_design_tokens.sh` → **0 violations in `lib/features/deep_link_targets`**
  (the script's other hits are pre-existing and belong to other lanes).
* Not run (other lanes are editing concurrently): repo-wide analyze, the full suite.
* Renders re-viewed before reporting via a throwaway golden probe at 440×956 in EN and AR
  (resolving frame, error frame, error frame RTL); the probe and its PNGs were deleted.
