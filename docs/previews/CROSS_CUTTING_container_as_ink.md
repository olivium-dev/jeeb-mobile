# Cross-cutting: a container role used as ink (15 call sites)

`lib/core/theme/app_theme.dart:87` states the rule in the codebase's own words:

> Anything that wants to PAINT ... must use `tertiary`, never a `*Container` role.

15 call sites break it. They are invisible in every light-only review because
`AppTheme.light()` hard-pins `secondaryContainer` to brand navy (17.13:1 on white),
while `AppTheme.dark()` derives it via `ColorScheme.fromSeed`, where it resolves to a
dark container tone on a near-identical dark surface — repeatedly measured at 1.98:1,
below even the 3:1 large-text floor.

This is one lint, not 15 fixes. Enumerated from source, not from the wave notes:
```
features/registration/presentation/registration_screen.dart:423:          color: colorScheme.secondaryContainer,
features/rating/presentation/rating_screen.dart:273:        color: theme.colorScheme.secondaryContainer,
features/rating/presentation/widgets/feedback_header.dart:42:        color: theme.colorScheme.secondaryContainer,
features/chat/presentation/widgets/confirm_delivery_action_sheet.dart:230:              color: theme.colorScheme.secondaryContainer,
features/chat/presentation/widgets/chat_fee_banner.dart:70:        color: colorScheme.secondaryContainer,
features/voice_request/presentation/voice_recording_screen.dart:505:        color: colorScheme.secondaryContainer,
features/delivery_man_profile/presentation/widgets/delivery_reviews_header.dart:49:        color: theme.colorScheme.secondaryContainer,
features/delivery_man_profile/presentation/widgets/delivery_man_profile_header.dart:258:          color: theme.colorScheme.secondaryContainer,
features/customer_profile/presentation/widgets/customer_profile_section_header.dart:24:          color: theme.colorScheme.secondaryContainer,
features/customer_profile/presentation/widgets/customer_profile_header.dart:162:          color: theme.colorScheme.secondaryContainer,
features/customer_profile/presentation/widgets/customer_profile_icon_disc.dart:19:        color: colorScheme.secondaryContainer,
features/home_client/presentation/widgets/pending_request_card.dart:84:              color: theme.colorScheme.secondaryContainer,
features/home_client/presentation/widgets/replies_card.dart:93:              color: theme.colorScheme.secondaryContainer,
features/jeeber_request_feed/presentation/pending_offer_row.dart:114:          color: theme.colorScheme.secondaryContainer,
features/jeeber_home/presentation/widgets/jeeber_feed_empty_view.dart:171:        color: theme.colorScheme.secondaryContainer,
```

Six were caught as individual findings across waves 02-11 before the pattern was
enumerated; the other nine have never been reported by anything.
