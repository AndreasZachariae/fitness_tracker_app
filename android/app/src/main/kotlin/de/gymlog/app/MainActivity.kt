package de.gymlog.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /** The open request for "Geräte in der Nähe" (1.6.3). */
    private var bluetoothResult: MethodChannel.Result? = null

    private val bluetoothPermissions =
        arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)

    private fun bluetoothGranted(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            bluetoothPermissions.all { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != BLUETOOTH_REQUEST) return
        val result = bluetoothResult ?: return
        bluetoothResult = null
        result.success(
            when {
                bluetoothGranted() -> "granted"
                // Denied and Android will not ask again: only the app settings help.
                bluetoothPermissions.none { shouldShowRequestPermissionRationale(it) } -> "blocked"
                else -> "denied"
            },
        )
    }

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
                            val amplitude = call.argument<Number>("amplitude")?.toInt() ?: 255
                            RestAlarm.schedule(applicationContext, atMillis.toLong(), amplitude)
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
                    // 1.6.3: "Geräte in der Nähe" asked by GymLog itself; in the shrunk release app the plugin's
                    // request never showed a dialog.
                    "bluetoothGranted" -> result.success(bluetoothGranted())
                    "requestBluetooth" -> when {
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.S -> result.success("denied")
                        bluetoothGranted() -> result.success("granted")
                        bluetoothResult != null -> result.error("busy", "request in progress", null)
                        else -> {
                            bluetoothResult = result
                            requestPermissions(bluetoothPermissions, BLUETOOTH_REQUEST)
                        }
                    }
                    "openAppSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        // Update APK via the system download manager (1.6.1); installing stays with the user. Off the main
        // thread: checking a finished APK copies it (1.6.2).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ApkDownloads.CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "openFolder") {
                    ApkDownloads.openFolder(this)
                    result.success(null)
                    return@setMethodCallHandler
                }
                val main = Handler(Looper.getMainLooper())
                Thread {
                    try {
                        val value: Any? = when (call.method) {
                            "start" -> ApkDownloads.start(
                                applicationContext,
                                call.argument<String>("url")!!,
                                call.argument<String>("name")!!,
                                call.argument<String>("version")!!,
                                call.argument<Map<String, Any?>>("done") ?: emptyMap(),
                            )
                            "query" -> ApkDownloads.query(
                                applicationContext,
                                call.argument<Number>("id")!!.toLong(),
                            )
                            "removeAll" -> {
                                ApkDownloads.removeAll(applicationContext)
                                null
                            }
                            else -> {
                                main.post { result.notImplemented() }
                                return@Thread
                            }
                        }
                        main.post { result.success(value) }
                    } catch (e: Exception) {
                        main.post { result.error("download", e.message, null) }
                    }
                }.start()
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

    private companion object {
        const val BLUETOOTH_REQUEST = 4711
    }
}
