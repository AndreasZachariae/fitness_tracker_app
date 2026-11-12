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
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import java.io.File

/**
 * Update APK via Android's download manager (1.6.1): the system downloads and shows the progress; the user
 * taps the file in the folder Download/GymLog and Android installs it. GymLog itself never installs anything
 * (no REQUEST_INSTALL_PACKAGES, Play Protect, 1.2.2).
 *
 * 1.6.2: The system's "Download abgeschlossen" notification opened the installer with the media provider as
 * source, which cannot be allowed to install apps. Instead [DownloadDoneReceiver] shows GymLog's own
 * notification that opens the folder; the file manager there is the source (allowed once by the user).
 *
 * Only release files from GitHub. At most one APK is kept: older GymLog downloads are removed
 * (with their files) before a new one starts.
 *
 * 1.6.2: The fixed address of the DEV APK (…/download/dev/gymlog-dev.apk) delivered the previous file for a
 * while after a new upload (GitHub's cache). Therefore the download uses the asset's own API address (new for
 * every upload), and a finished file only counts when the version inside the APK is the expected one
 * ("stale" otherwise: removed, "try again later").
 */
object ApkDownloads {
    const val CHANNEL = "de.gymlog.app/downloads"
    const val FOLDER = "GymLog"
    private const val APK_TYPE = "application/vnd.android.package-archive"

    private fun manager(context: Context) =
        context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

    private const val PREFS = "apk_downloads"

    private val ASSET_PATH = Regex("^/repos/[^/]+/[^/]+/releases/assets/\\d+$")

    /** A release file on GitHub: the download address (github.com) or the asset in the API. */
    fun isGitHubFile(uri: Uri): Boolean =
        uri.scheme == "https" &&
            (uri.host == "github.com" || (uri.host == "api.github.com" && ASSET_PATH.matches(uri.path ?: "")))

    /** Starts (or resumes showing) the download of [url] as [name] (with the version, 1.6.2); returns its id.
     *  [version] is the one the APK must contain. [done] holds the texts of the notifications at the end
     *  (from Dart, where all texts live). */
    fun start(context: Context, url: String, name: String, version: String, done: Map<String, Any?>): Long {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().apply {
            for ((key, value) in done) putString(key, value?.toString())
        }.apply()
        val uri = Uri.parse(url)
        require(isGitHubFile(uri)) { "not a GitHub release file" }
        require(Regex("^gymlog-[A-Za-z0-9._-]+\\.apk$").matches(name)) { "bad file name" }
        val dm = manager(context)
        // The same version still running or already there: keep it. The URL alone is not enough: the DEV
        // release always has the same one (1.6.2).
        sameFile(dm, url, name)?.let { return it }
        removeAll(context)
        val request = DownloadManager.Request(uri)
            // The API answers with the file itself (a redirect) only for this type.
            .addRequestHeader("Accept", "application/octet-stream")
            .setTitle(name)
            .setMimeType(APK_TYPE)
            // Progress only; the end is announced by GymLog (see above).
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, "$FOLDER/$name")
        } else {
            request.setDestinationInExternalFilesDir(context, Environment.DIRECTORY_DOWNLOADS, name)
        }
        val id = dm.enqueue(request)
        prefs.edit().putString("expected_$id", version).apply()
        return id
    }

    private fun sameFile(dm: DownloadManager, url: String, name: String): Long? {
        dm.query(DownloadManager.Query()).use { c ->
            while (c.moveToNext()) {
                if (c.string(DownloadManager.COLUMN_URI) != url) continue
                if (c.string(DownloadManager.COLUMN_TITLE) != name) continue
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
            var found: String? = null
            val status = when (c.int(DownloadManager.COLUMN_STATUS)) {
                DownloadManager.STATUS_SUCCESSFUL -> {
                    found = check(context, id)
                    if (found == null) "done" else "stale"
                }
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
                "found" to found,
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

    /** The folder Download/GymLog as a document URI. */
    private fun folderView(): Intent {
        val uri = DocumentsContract.buildDocumentUri(
            "com.android.externalstorage.documents",
            "primary:${Environment.DIRECTORY_DOWNLOADS}/$FOLDER",
        )
        return Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, DocumentsContract.Document.MIME_TYPE_DIR)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }

    /**
     * Where the user taps the APK (1.6.2): the folder in the system's "Dateien", which opens it directly (Files by
     * Google cannot open a subfolder, tested by the human); without it the system list of downloads.
     */
    fun folderIntent(context: Context): Intent {
        val folder = folderView()
        val chosen = if (folder.resolveActivity(context.packageManager) != null) {
            folder
        } else {
            Intent(DownloadManager.ACTION_VIEW_DOWNLOADS)
        }
        return chosen.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    fun openFolder(context: Context) {
        try {
            context.startActivity(folderIntent(context))
        } catch (_: ActivityNotFoundException) {
            context.startActivity(
                Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    /** Version inside the downloaded APK [id], read from a copy in the cache; null if unreadable. */
    private fun apkVersion(context: Context, dm: DownloadManager, id: Long): String? = try {
        val copy = File(context.cacheDir, "update-check.apk")
        ParcelFileDescriptor.AutoCloseInputStream(dm.openDownloadedFile(id)).use { input ->
            copy.outputStream().use { input.copyTo(it) }
        }
        @Suppress("DEPRECATION")
        val info = context.packageManager.getPackageArchiveInfo(copy.path, 0)
        copy.delete()
        info?.versionName
    } catch (_: Exception) {
        null
    }

    /**
     * Checks a finished download once: null if it holds the expected version (or nothing to compare), else the
     * version found – then the download and its file are removed (1.6.2).
     */
    @Synchronized
    fun check(context: Context, id: Long): String? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.getString("checked_$id", null)?.let { return it.ifEmpty { null } }
        val expected = prefs.getString("expected_$id", null)
        val dm = manager(context)
        val found = expected?.let { apkVersion(context, dm, id) }
        val stale = if (expected != null && found != null && found != expected) found else null
        prefs.edit().putString("checked_$id", stale ?: "").apply()
        if (stale != null) dm.remove(id)
        return stale
    }

    /** GymLog's notification for download [id], if it is a finished APK: "Update geladen", or "noch die
     *  vorige Version" when the check fails (1.6.2). */
    fun notifyDone(context: Context, id: Long) {
        val dm = manager(context)
        dm.query(DownloadManager.Query().setFilterById(id)).use { c ->
            if (!c.moveToFirst()) return
            if (c.int(DownloadManager.COLUMN_STATUS) != DownloadManager.STATUS_SUCCESSFUL) return
            if (c.string(DownloadManager.COLUMN_MEDIA_TYPE) != APK_TYPE) return
        }
        val stale = check(context, id) != null
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val title = prefs.getString(if (stale) "staleTitle" else "title", null) ?: return
        val body = prefs.getString(if (stale) "staleBody" else "body", null) ?: return
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
            folderIntent(context),
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
            .apply { if (!stale) setContentIntent(open) }
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
        if (id < 0) return
        // Checking the version copies the APK: not on the main thread.
        val pending = goAsync()
        Thread {
            try {
                ApkDownloads.notifyDone(context.applicationContext, id)
            } finally {
                pending.finish()
            }
        }.start()
    }
}
