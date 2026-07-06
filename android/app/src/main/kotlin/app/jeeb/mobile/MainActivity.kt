package app.jeeb.mobile

import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val seamChannelName = "app.jeeb.mobile/dev_seam"

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

    // Jeeber Dev Tool launcher routing: when this activity was started via the
    // `.DevToolLauncher` activity-alias (the Dev Tool icon), hand Flutter the
    // "/devtool" initial route so lib/main.dart boots the Dev Tool shell instead
    // of the product app. Any other launch (the normal app icon, a deep link)
    // falls through to the default FlutterActivity behaviour.
    override fun getInitialRoute(): String? {
        if (componentName?.className == "app.jeeb.mobile.DevToolLauncher") {
            return "/devtool"
        }
        return super.getInitialRoute()
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
