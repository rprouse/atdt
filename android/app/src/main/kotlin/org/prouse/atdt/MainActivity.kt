package org.prouse.atdt

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    /** Set from Dart while a reader is open with volume paging turned on. */
    private var volumePaging = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "org.prouse.atdt/volume_keys",
        ).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "setEnabled") {
                    volumePaging = call.arguments as? Boolean ?: false
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    // The activity sees keys before the FlutterView does. Consuming them here
    // is the only reliable way to stop Android also changing the volume.
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val direction = when (event.keyCode) {
            KeyEvent.KEYCODE_VOLUME_DOWN -> 1
            KeyEvent.KEYCODE_VOLUME_UP -> -1
            else -> 0
        }
        if (!volumePaging || direction == 0) return super.dispatchKeyEvent(event)
        if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
            channel?.invokeMethod("page", direction)
        }
        return true
    }
}
