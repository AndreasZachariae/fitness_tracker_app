package de.gymlog.app

import android.os.Build
import android.os.Handler
import android.os.Looper
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
        // Update APK via the system download manager (1.6.1); installing stays with the user.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ApkDownloads.CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "start" -> result.success(
                            ApkDownloads.start(
                                applicationContext,
                                call.argument<String>("url")!!,
                                call.argument<Map<String, Any?>>("done") ?: emptyMap(),
                            ),
                        )
                        "query" -> result.success(
                            ApkDownloads.query(applicationContext, call.argument<Number>("id")!!.toLong()),
                        )
                        "removeAll" -> {
                            ApkDownloads.removeAll(applicationContext)
                            result.success(null)
                        }
                        "openFolder" -> {
                            ApkDownloads.openFolder(this)
                            result.success(null)
                        }
                        "openInstallSettings" -> {
                            ApkDownloads.openInstallSettings(this)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("download", e.message, null)
                }
            }
        // Backups and exports into Download/GymLog (1.6.1), off the main thread.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DownloadsFolder.CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveToDownloads") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val name = call.argument<String>("name")!!
                val mimeType = call.argument<String>("mimeType")!!
                val bytes = call.argument<ByteArray>("bytes")!!
                val main = Handler(Looper.getMainLooper())
                Thread {
                    try {
                        val where = DownloadsFolder.save(applicationContext, name, mimeType, bytes)
                        main.post { result.success(where) }
                    } catch (e: Exception) {
                        main.post { result.error("save", e.message, null) }
                    }
                }.start()
            }
    }
}
