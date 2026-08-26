package com.olivium.jeeb

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class DevToolLauncher : FlutterFragmentActivity() {
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
    }
}
