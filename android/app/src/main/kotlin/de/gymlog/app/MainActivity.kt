package de.gymlog.app

import android.os.Build
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
        // Android version for the heart rate monitor (Bluetooth without location only from Android 12, 1.5.0).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "de.gymlog.app/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    else -> result.notImplemented()
                }
            }
    }
}
