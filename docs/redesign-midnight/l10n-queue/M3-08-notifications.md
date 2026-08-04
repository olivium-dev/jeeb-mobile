# l10n queue — M3-08 · notifications-list

New keys the Midnight restyle needs. **Not written to `lib/l10n/*.arb`** (the l10n
lane owns it). Each site currently renders the nearest existing string and carries
`TODO(midnight): l10n-queued`.

| Key | EN | AR | Site |
|---|---|---|---|
| `notificationsLoadingHeadline` | `Loading notifications` | `جارٍ تحميل الإشعارات` | `notifications_list_screen.dart` loading `_StateBlock` headline — today renders `notificationsTitle` ("Notifications"), which duplicates the top bar. |
| `notificationsErrorTitle` | `Couldn't load notifications` | `تعذّر تحميل الإشعارات` | error `_StateBlock` headline — today renders `NotificationsL10n.loadError`, whose copy is the same sentence but ends in a full stop, so it reads as a body line in `h1`. |

## Migration note (no code change requested)

`NotificationsL10n` (`lib/features/notifications/presentation/notifications_l10n.dart`)
carries ~20 strings as inline `_pick(en, ar)` pairs that were never lifted into the
ARB — `loadError`, `networkError`, `retry`, `unreadLabel`, `categoryLabel(kind)` ×14,
`newRequestFallbackTitle/Body`, and the whole `relativeTime` ladder (`12m ago` /
`قبل ١٢ د`). The Midnight restyle promotes three of them to first-class surface copy
(error headline, error body, retry CTA label), so they are now visually prominent
rather than incidental. Worth folding into the ARB in the same pass as the two keys
above; M3-08 did not touch the file.
