package com.olivium.jeeb

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

internal object InternalReleasePolicyChannel {
    private const val CHANNEL_NAME = "com.olivium.jeeb/internal_release"
    private const val INTERNAL_FLAVOR = "internalRelease"

    fun register(
        context: Context,
        engine: FlutterEngine,
        dedicatedLauncher: Boolean,
    ) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                if (call.method != "readPolicy") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                result.success(snapshot(context, dedicatedLauncher))
            }
    }

    fun allowsInternalTool(context: Context): Boolean =
        snapshot(context, dedicatedLauncher = true).values.all { it }

    private fun snapshot(
        context: Context,
        dedicatedLauncher: Boolean,
    ): Map<String, Boolean> = mapOf(
        "releaseBuild" to !BuildConfig.DEBUG,
        "internalFlavor" to (
            BuildConfig.JEEB_INTERNAL_RELEASE &&
                BuildConfig.FLAVOR == INTERNAL_FLAVOR
            ),
        "internalResource" to context.resources.getBoolean(
            R.bool.jeeb_internal_release
        ),
        "dedicatedLauncher" to dedicatedLauncher,
    )
}
