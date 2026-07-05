package app.jeeb.mobile

import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

/**
 * DEV-FLAVOR-ONLY launcher target for the "Jeeb Dev Tool" testing app.
 *
 * Declared in `android/app/src/dev/AndroidManifest.xml` (the `dev` source set),
 * so it only exists on dev builds. Instead of the product entrypoint it boots
 * the Dart `mainDevTool()` function (declared in lib/main.dart so the build
 * compiles it into the kernel), which runs a pure-UI testing tool over mocked
 * data — no Firebase/DI bootstrap.
 *
 * The window edge-to-edge setup mirrors MainActivity.onCreate so the tool
 * renders in the same chrome as the real app.
 */
class DevToolActivity : FlutterActivity() {
    // mainDevTool() is declared in lib/main.dart (the default entrypoint
    // library), so only the function name is needed — no library-URI override.
    override fun getDartEntrypointFunctionName(): String = "mainDevTool"

    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
        super.onCreate(savedInstanceState)
    }
}
