package de.gymlog.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Rest-over vibration while the app is in the background (1.0.1).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RestAlarm.CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedule" -> {
                        val atMillis = call.argument<Number>("atMillis")
                        if (atMillis == null) {
                            result.error("args", "atMillis missing", null)
                        } else {
                            RestAlarm.schedule(applicationContext, atMillis.toLong())
                            result.success(null)
                        }
                    }
                    "cancel" -> {
                        RestAlarm.cancel(applicationContext)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
