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
        "jeeb.route",
        "jeeb.state",
        "jeeb.locale",
        "jeeb.home_tab",
        "jeeb.feed",
        "jeeb.hold_splash",
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
