# Wiring requests — 21 · Order chat

### l10n
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb + lib/l10n/app_localizations.dart
need: seven new strings for the redesigned order chat — the read-state word, three quick replies,
the quick-reply row a11y name, the timestamped system chip, and the counterpart-rating a11y label.
exact change:
app_en.arb —
```json
  "chatMessageReadLabel": "Read",
  "@chatMessageReadLabel": { "description": "Outgoing-bubble read state rendered as text in the meta line (JeebChatStatus.text — the read state is a word, never a tick; readTick is banned). Semantics id chat_detail_message_read is unchanged." },
  "chatQuickReplyImHome": "I'm home",
  "@chatQuickReplyImHome": { "description": "Quick-reply pill order_chat_quick_reply_home; tapping sends this exact text as a chat message." },
  "chatQuickReplyCallAtDoor": "Call me at the door",
  "@chatQuickReplyCallAtDoor": { "description": "Quick-reply pill order_chat_quick_reply_door; tapping sends this exact text as a chat message." },
  "chatQuickReplyThanks": "شكراً",
  "@chatQuickReplyThanks": { "description": "Quick-reply pill order_chat_quick_reply_thanks. DELIBERATELY Arabic in BOTH locales — the board draws the Arabic pill inside the English thread (designer note: 'one-tap quick replies incl. Arabic'). PRODUCT CHOICE pending owner confirmation; if refused, ship EN \"Thanks\"." },
  "chatQuickReplyRowA11y": "Quick replies",
  "@chatQuickReplyRowA11y": { "description": "Accessible name of the quick-reply row container (order_chat_quick_reply_row)." },
  "chatSystemChipWithTime": "{event} · {time}",
  "@chatSystemChipWithTime": { "description": "System timeline chip with a server timestamp, e.g. 'Offer accepted · 9:12'. Rendered ONLY when the message has a server timestamp (chat_undated_band_contract). {event} is existing localized system copy; {time} is DateFormat.Hm output.", "placeholders": { "event": { "type": "String", "example": "Offer accepted" }, "time": { "type": "String", "example": "9:12" } } },
  "chatCounterpartRatingA11y": "Rating {value} out of 5",
  "@chatCounterpartRatingA11y": { "description": "Accessible label for the chat header's counterpart star rating line (★ 4.9). The visible glyph+number are ExcludeSemantics'd behind this.", "placeholders": { "value": { "type": "String", "example": "4.9" } } },
```
app_ar.arb —
```json
  "chatMessageReadLabel": "تمت القراءة",
  "chatQuickReplyImHome": "أنا في المنزل",
  "chatQuickReplyCallAtDoor": "اتصل بي عند الباب",
  "chatQuickReplyThanks": "شكراً",
  "chatQuickReplyRowA11y": "ردود سريعة",
  "chatSystemChipWithTime": "{event} · {time}",
  "chatCounterpartRatingA11y": "التقييم {value} من 5",
```
app_localizations.dart (house pattern — hand-rolled `_get` + `replaceFirst`, no ICU) —
```dart
  String get chatMessageReadLabel => _get('chatMessageReadLabel');
  String get chatQuickReplyImHome => _get('chatQuickReplyImHome');
  String get chatQuickReplyCallAtDoor => _get('chatQuickReplyCallAtDoor');
  String get chatQuickReplyThanks => _get('chatQuickReplyThanks');
  String get chatQuickReplyRowA11y => _get('chatQuickReplyRowA11y');
  String chatSystemChipWithTime(String event, String time) => _get('chatSystemChipWithTime')
      .replaceFirst('{event}', event)
      .replaceFirst('{time}', time);
  String chatCounterpartRatingA11y(String value) =>
      _get('chatCounterpartRatingA11y').replaceFirst('{value}', value);
```
why: the read state becomes the literal word (kit `JeebChatStatus.text` — `readTick` has zero
board occurrences and is banned); the quick-reply row is a net-new surface whose pill labels are
the sent message text; the system chips gain the board's `· 9:12` suffix; the header's ★ 4.9 needs
a screen-reader sentence. All rendered by `lib/features/chat/**` code already written against
these getters.

### cross-feature (ADVISORY — no file change requested from the integrator)
file: .maestro/flows/02-chat-client.yaml:175, .maestro/flows/03-chat-after-aproval-client.yaml:179, .maestro/flows/04-delivery-screen-chat-delivery-man.yaml:92, .maestro/flows/07-chat-dm-blank.yaml:128
need: E2E owner attention — these four flows still `assertVisible: id: "chat_detail_voice_button"`, an identifier that has been deliberately absent since B-04 shipped (the mic was removed; `test/features/chat/chat_composer_no_mic_b04_test.dart` asserts its absence). They have been stale since before this redesign and Maestro is not in CI.
exact change: none from the integrator; the E2E owner should delete the four `chat_detail_voice_button` assertions (and the flow comments naming it) when they next touch these flows. The 21 lane keeps send-not-mic per B-04 and did not edit `.maestro/**`.
why: prevents the flows being "fixed" by resurrecting the mic — the Dart guard wins; the redesigned composer (kit `JeebChatComposer`) enforces no-mic structurally.
