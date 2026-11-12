package de.gymlog.app

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Environment

/**
 * Update APK via Android's download manager (1.6.1): the system downloads, shows the progress and a
 * "Download abgeschlossen" notification; the user taps the file and Android installs it. GymLog itself
 * never installs anything (no REQUEST_INSTALL_PACKAGES, Play Protect, 1.2.2).
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

    /** Starts (or resumes showing) the download of [url]; returns its id. */
    fun start(context: Context, url: String): Long {
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
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
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

    /** The system list of downloads, where the user taps the APK. */
    fun openDownloads(context: Context) {
        context.startActivity(
            Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    private fun Cursor.string(column: String): String? = getString(getColumnIndexOrThrow(column))
    private fun Cursor.long(column: String): Long = getLong(getColumnIndexOrThrow(column))
    private fun Cursor.int(column: String): Int = getInt(getColumnIndexOrThrow(column))
}
