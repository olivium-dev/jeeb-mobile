# `dev` flavor Firebase config

`google-services.json` is the real Firebase configuration for the Android app
`app.jeeb.mobile.dev` in Firebase project `jeeb-5a293`. The Android app was
registered and its configuration downloaded through the Firebase Management
API.

The `dev` flavor sets `applicationIdSuffix ".dev"`. The Google Services Gradle
plugin therefore selects this flavor-specific file for `devDebug` and matches
its `app.jeeb.mobile.dev` client. Firebase Cloud Messaging token retrieval and
push notifications work on `devDebug` with this configuration.

Keep future replacements scoped to this source set and ensure the client package
remains `app.jeeb.mobile.dev`.
