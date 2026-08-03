# Wiring requests — w4 · client-unreachable

**Nothing here blocks the lane.** `dart analyze lib/features/client_unreachable` is clean and the
new `test/client_unreachable_screen_test.dart` (4 tests) passes today: the six strings live in the
feature-local `ClientUnreachableL10n._pick(en, ar)` map, the same stopgap mechanism as
`live_tracking_l10n.dart` (this screen's journey neighbour) and `dispute_status_l10n.dart`.

### l10n — 6 keys (the whole screen)

file: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`, `lib/l10n/app_localizations.dart`

why: `client_unreachable_screen.dart` had **zero** ARB keys — all six strings were inlined in
English at the call site, so an Arabic user read English on this surface. The re-skin did not
change any wording (constraint: "no changed copy meaning"), it only moved the strings into a
resolver that can carry the AR side. The EN values below are byte-identical to what shipped.

`app_en.arb` — add (append-only):

```json
"clientUnreachableTitle": "Client Unreachable",
"@clientUnreachableTitle": { "description": "client_unreachable top-bar title (jeeber flags a client who is not answering at the door)." },
"clientUnreachableNoticeTitle": "Cannot reach the Client",
"@clientUnreachableNoticeTitle": { "description": "client_unreachable notice headline — the state the jeeber is in." },
"clientUnreachableNoticeBody": "If the Client is not responding, you can flag them as unreachable. They will have 15 minutes to respond before the delivery is escalated.",
"@clientUnreachableNoticeBody": { "description": "client_unreachable notice body — what flagging does and the 15-minute grace window before escalation." },
"clientUnreachableCallAgainCta": "Try Calling Again",
"@clientUnreachableCallAgainCta": { "description": "client_unreachable_call_again_cta — retry the phone call." },
"clientUnreachableChatCta": "Send Chat Message",
"@clientUnreachableChatCta": { "description": "client_unreachable_chat_cta — reach the client in the order chat instead." },
"clientUnreachableFlagCta": "Flag as Unreachable",
"@clientUnreachableFlagCta": { "description": "client_unreachable_flag_cta — the docked escalating edge; pops true to the caller." }
```

`app_ar.arb` — add:

```json
"clientUnreachableTitle": "تعذّر الوصول إلى العميل",
"clientUnreachableNoticeTitle": "لا يمكن الوصول إلى العميل",
"clientUnreachableNoticeBody": "إذا لم يستجب العميل، يمكنك الإبلاغ عن تعذّر الوصول إليه. سيكون أمامه 15 دقيقة للرد قبل تصعيد التوصيل.",
"clientUnreachableCallAgainCta": "حاول الاتصال مجددًا",
"clientUnreachableChatCta": "إرسال رسالة في المحادثة",
"clientUnreachableFlagCta": "الإبلاغ عن تعذّر الوصول"
```

`app_localizations.dart` — add six getters (hand-authored runtime parser; **no `flutter gen-l10n`**),
matching the neighbouring getter style verbatim:

```dart
String get clientUnreachableTitle => _get('clientUnreachableTitle');
String get clientUnreachableNoticeTitle => _get('clientUnreachableNoticeTitle');
String get clientUnreachableNoticeBody => _get('clientUnreachableNoticeBody');
String get clientUnreachableCallAgainCta => _get('clientUnreachableCallAgainCta');
String get clientUnreachableChatCta => _get('clientUnreachableChatCta');
String get clientUnreachableFlagCta => _get('clientUnreachableFlagCta');
```

**On grant**, delete `lib/features/client_unreachable/presentation/client_unreachable_l10n.dart`
and read `AppLocalizations.of(context)` directly in the screen — all edits stay inside this lane's
own directory. `test/client_unreachable_screen_test.dart`'s host would then need
`AppLocalizations.delegate` added to its `localizationsDelegates`.

No other shared file is needed: no route, no DI, no theme, no kit, no pubspec change.
