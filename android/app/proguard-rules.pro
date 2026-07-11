# Release (R8) keep rules for the Jeeb Android app.
# Referenced by android/app/build.gradle buildTypes.release.proguardFiles.
# Firebase (messaging/crashlytics/installations) and google_maps_flutter ship
# their own consumer ProGuard rules, so only defensive keeps live here.

# --- Flutter embedding -------------------------------------------------------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- Google Maps SDK for Android (google_maps_flutter) -----------------------
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }
-dontwarn com.google.android.gms.**

# --- Firebase Cloud Messaging / Crashlytics ----------------------------------
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
