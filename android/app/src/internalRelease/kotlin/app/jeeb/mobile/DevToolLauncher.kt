package com.olivium.jeeb

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class DevToolLauncher : FlutterFragmentActivity() {
    private var devToolChannel: MethodChannel? = null

    override fun getInitialRoute(): String =
        if (InternalReleasePolicyChannel.allowsInternalTool(this)) {
            "/devtool"
        } else {
            "/"
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        InternalReleasePolicyChannel.register(
            context = this,
            engine = flutterEngine,
            dedicatedLauncher = true,
        )
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
