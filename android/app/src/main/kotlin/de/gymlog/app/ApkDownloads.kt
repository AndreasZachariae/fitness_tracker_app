package de.gymlog.app

import android.app.DownloadManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.Settings

/**
 * Update APK via Android's download manager (1.6.1): the system downloads and shows the progress; the user
 * taps the file in the folder Download/GymLog and Android installs it. GymLog itself never installs anything
 * (no REQUEST_INSTALL_PACKAGES, Play Protect, 1.2.2).
 *
 * 1.6.2: The system's "Download abgeschlossen" notification opened the installer with the media provider as
 * source, which cannot be allowed to install apps. Instead [DownloadDoneReceiver] shows GymLog's own
 * notification that opens the folder; the file manager there is the source (allowed once by the user).
 *
 * Only release files from github.com. At most one APK is kept: older GymLog downloads are removed
 * (with their files) before a new one starts.
 */
object ApkDownloads {
    const val CHANNEL = "de.gymlog.app/downloads"
    const val FOLDER = "GymLog"
    private const val APK_TYPE = "application/vnd.android.package-archive"

    private fun manager(context: Context) =
        context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

    private const val PREFS = "apk_downloads"

    /** Starts (or resumes showing) the download of [url]; returns its id. [done] holds the texts of the
     *  notification at the end (from Dart, where all texts live). */
    fun start(context: Context, url: String, done: Map<String, Any?>): Long {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().apply {
            for ((key, value) in done) putString(key, value?.toString())
        }.apply()
        val uri = Uri.parse(url)
        require(uri.scheme == "https" && uri.host == "github.com") { "not a GitHub release file" }
        val name = uri.lastPathSegment?.takeIf { it.endsWith(".apk") } ?: "gymlog.apk"
        val dm = manager(context)
        // The same file still running or already there: keep it.
        sameUrl(dm, url)?.let { return it }
        removeAll(context)
        val request = DownloadManager.Request(uri)
            .setTitle(name)
            .setMimeType(APK_TYPE)
            // Progress only; the end is announced by GymLog (see above).
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, "$FOLDER/$name")
        } else {
            request.setDestinationInExternalFilesDir(context, Environment.DIRECTORY_DOWNLOADS, name)
        }
        return dm.enqueue(request)
    }

    private fun sameUrl(dm: DownloadManager, url: String): Long? {
        dm.query(DownloadManager.Query()).use { c ->
            while (c.moveToNext()) {
                if (c.string(DownloadManager.COLUMN_URI) != url) continue
                val id = c.long(DownloadManager.COLUMN_ID)
                when (c.int(DownloadManager.COLUMN_STATUS)) {
                    DownloadManager.STATUS_FAILED -> continue
                    DownloadManager.STATUS_SUCCESSFUL -> {
                        // Deleted by the user meanwhile: download again.
                        val exists = try {
                            dm.openDownloadedFile(id).close()
                            true
                        } catch (_: Exception) {
                            false
                        }
                        if (exists) return id
                    }
                    else -> return id
                }
            }
        }
        return null
    }

    /** State of download [id] for the progress bar; null if unknown. */
    fun query(context: Context, id: Long): Map<String, Any?>? {
        manager(context).query(DownloadManager.Query().setFilterById(id)).use { c ->
            if (!c.moveToFirst()) return null
            val status = when (c.int(DownloadManager.COLUMN_STATUS)) {
                DownloadManager.STATUS_SUCCESSFUL -> "done"
                DownloadManager.STATUS_FAILED -> "failed"
                DownloadManager.STATUS_RUNNING -> "running"
                DownloadManager.STATUS_PAUSED -> "paused"
                else -> "pending"
            }
            val local = c.string(DownloadManager.COLUMN_LOCAL_URI)?.let { Uri.parse(it).lastPathSegment }
            return mapOf(
                "status" to status,
                "received" to c.long(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR),
                "total" to c.long(DownloadManager.COLUMN_TOTAL_SIZE_BYTES),
                "file" to local,
            )
        }
    }

    /** Removes all APK downloads of GymLog, files included. */
    fun removeAll(context: Context) {
        val dm = manager(context)
        val ids = mutableListOf<Long>()
        dm.query(DownloadManager.Query()).use { c ->
            while (c.moveToNext()) {
                if (c.string(DownloadManager.COLUMN_MEDIA_TYPE) == APK_TYPE) {
                    ids.add(c.long(DownloadManager.COLUMN_ID))
                }
            }
        }
        if (ids.isNotEmpty()) dm.remove(*ids.toLongArray())
    }

    /** The folder Download/GymLog in the file manager, where the user taps the APK (1.6.2). */
    fun folderIntent(): Intent {
        val uri = DocumentsContract.buildDocumentUri(
            "com.android.externalstorage.documents",
            "primary:${Environment.DIRECTORY_DOWNLOADS}/$FOLDER",
        )
        return Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, DocumentsContract.Document.MIME_TYPE_DIR)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }

    /** Opens the folder; without a file manager for it the system list of downloads. */
    fun openFolder(context: Context) {
        try {
            context.startActivity(folderIntent())
        } catch (_: ActivityNotFoundException) {
            context.startActivity(
                Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    /** Android's list "Unbekannte Apps installieren", where the user allows the file manager once. */
    fun openInstallSettings(context: Context) {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
        } else {
            Intent(Settings.ACTION_SECURITY_SETTINGS)
        }
        try {
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (_: ActivityNotFoundException) {
            context.startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    /** GymLog's notification "Update geladen" for download [id], if it is a finished APK. */
    fun notifyDone(context: Context, id: Long) {
        val dm = manager(context)
        dm.query(DownloadManager.Query().setFilterById(id)).use { c ->
            if (!c.moveToFirst()) return
            if (c.int(DownloadManager.COLUMN_STATUS) != DownloadManager.STATUS_SUCCESSFUL) return
            if (c.string(DownloadManager.COLUMN_MEDIA_TYPE) != APK_TYPE) return
        }
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val title = prefs.getString("title", null) ?: return
        val body = prefs.getString("body", null) ?: return
        val channelId = prefs.getString("channelId", null) ?: return
        val channelName = prefs.getString("channelName", null) ?: channelId
        val notificationId = prefs.getString("notificationId", null)?.toIntOrNull() ?: return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && nm.getNotificationChannel(channelId) == null) {
            nm.createNotificationChannel(
                NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_DEFAULT),
            )
        }
        val open = PendingIntent.getActivity(
            context,
            0,
            folderIntent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(context, channelId)
        } else {
            android.app.Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(android.app.Notification.BigTextStyle().bigText(body))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        try {
            nm.notify(notificationId, notification)
        } catch (_: SecurityException) {
            // Notifications not allowed: the update page shows the same.
        }
    }

    private fun Cursor.string(column: String): String? = getString(getColumnIndexOrThrow(column))
    private fun Cursor.long(column: String): Long = getLong(getColumnIndexOrThrow(column))
    private fun Cursor.int(column: String): Int = getInt(getColumnIndexOrThrow(column))
}

/** The download manager's "download complete" (sent only to GymLog, guarded by the system permission in the
 *  manifest): GymLog's own notification for a finished update APK (1.6.2). */
class DownloadDoneReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != DownloadManager.ACTION_DOWNLOAD_COMPLETE) return
        val id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1)
        if (id >= 0) ApkDownloads.notifyDone(context, id)
    }
}
