package com.olivium.jeeb

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// JEBV4-213 (E18): the `local_auth` plugin's Android implementation renders the
// BiometricPrompt inside the host Activity and REQUIRES it to be a
// FragmentActivity — with the previous FlutterActivity base, authenticate()
// throws `local_auth plugin requires activity to be a FragmentActivity` at
// runtime. FlutterFragmentActivity is a drop-in replacement that keeps the same
// configureFlutterEngine / getInitialRoute / onCreate seam wiring below intact.
class MainActivity : FlutterFragmentActivity() {
    private val seamChannelName = "com.olivium.jeeb/dev_seam"

    // Samsung app-sleep silently drops FCM while the app is battery-restricted.
    private val powerChannelName = "com.olivium.jeeb/power"

    // Debug-only seam keys read from `adb shell am start … -e <key> <value>`.
    private val seamKeys = listOf(
        // Legacy capture knobs (route / chat-state / locale / tab / feed / splash).
        "jeeb.route",
        "jeeb.state",
        "jeeb.locale",
        "jeeb.home_tab",
        "jeeb.feed",
        "jeeb.hold_splash",
        // Wave 0 dev-seam session/journey harness (62_SEAM_HARNESS.md). These let
        // a Maestro flow deterministically start mid-journey by seeding app state
        // before the GoRouter first-run redirect fires. All are kDebugMode-gated
        // on the Dart side (DevSeamConfig) so release builds ignore them.
        "jeeb.seam.session",
        // Wave 1 journey seam (63_W1_TEST_PLAN §4): seeds mid-journey
        // request/offer/delivery/conversation state for user-client-001 (or
        // user-jeeber-002) so the core customer-journey flows start deep.
        "jeeb.seam.journey",
        // Wave 2 jeeber seam (65_W2_TEST_PLAN §3): seeds the jeeber KYC status
        // (the DELIVERY-tab + offer gates read) and the wallet affordability
        // state (the wallet hub + offer composer read). Both are kDebugMode-gated
        // on the Dart side (DevSeamConfig) so release builds ignore them.
        "jeeb.seam.kyc_status",
        "jeeb.seam.wallet_state",
        "jeeb.seam.otp_code",
        "jeeb.seam.otp_countdown_expired",
        "jeeb.seam.signup_collision",
        "jeeb.seam.social_login",
        "jeeb.seam.recovery_code",
        "jeeb.seam.recovery_countdown_expired",
        "jeeb.seam.set_password_mode",
    )

    // `adb push jeeb-dev-seam.json /data/local/tmp/jeeb-dev-seam.json`.
    private val seamFilePath = "/data/local/tmp/jeeb-dev-seam.json"

    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, seamChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readSeamExtras" -> result.success(readSeamExtras())
                    "readSeamFile" -> result.success(readSeamFile())
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, powerChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" ->
                        result.success(isIgnoringBatteryOptimizations())
                    "openBatteryOptimizationSettings" ->
                        result.success(openBatteryOptimizationSettings())
                    else -> result.notImplemented()
                }
            }
    }

    // PowerManager query needs no permission; false on the pre-M path.
    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return try {
            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
            power.isIgnoringBatteryOptimizations(packageName)
        } catch (error: Exception) {
            false
        }
    }

    // The SETTINGS list, not ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS: the
    // request intent needs a Play-policy-declared permission, the list needs none.
    private fun openBatteryOptimizationSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        return try {
            startActivity(
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            )
            true
        } catch (error: Exception) {
            false
        }
    }

    // Extracts only the recognised jeeb.* extras from the launch intent.
    private fun readSeamExtras(): Map<String, String> {
        val extras = intent?.extras ?: return emptyMap()
        val out = mutableMapOf<String, String>()
        for (key in seamKeys) {
            extras.getString(key)?.let { out[key] = it }
        }
        return out
    }

    // Reads the dev-seam JSON file if present; null when absent/unreadable so
    // the Dart side cleanly falls through to the next source.
    private fun readSeamFile(): String? {
        return try {
            val file = File(seamFilePath)
            if (file.exists() && file.canRead()) file.readText() else null
        } catch (error: Exception) {
            null
        }
    }
}
