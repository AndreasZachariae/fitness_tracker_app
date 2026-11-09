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
        // In-app update (1.2.2).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UpdateInstaller.CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "canInstall" -> result.success(UpdateInstaller.canInstall(this))
                        "openInstallSettings" -> {
                            UpdateInstaller.openInstallSettings(this)
                            result.success(null)
                        }
                        "install" -> {
                            UpdateInstaller.install(this, call.argument<String>("path")!!)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("update", e.message, null)
                }
            }
    }
}
