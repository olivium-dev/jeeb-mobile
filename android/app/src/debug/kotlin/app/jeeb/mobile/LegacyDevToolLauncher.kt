package com.olivium.jeeb

import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class LegacyDevToolLauncher : MainActivity() {
    private var devToolChannel: MethodChannel? = null

    override fun getInitialRoute(): String = "/devtool"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        devToolChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.olivium.jeeb/devtool_launcher",
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        devToolChannel?.invokeMethod("open", null)
    }
}
