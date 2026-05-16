# `lib/shared/`

Cross-feature widgets and utilities that don't fit inside a single feature
slice and aren't general enough to live in `lib/core/`.

Anything UI-facing here must compose **OMDS** components from
`package:omds/omds.dart` — raw Material widgets are banned per
`flutter-omds-design-system-usage`.
