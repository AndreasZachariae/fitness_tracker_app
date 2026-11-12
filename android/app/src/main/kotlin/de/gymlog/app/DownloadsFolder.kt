package de.gymlog.app

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File

/**
 * Backups and exports straight into Download/GymLog (1.6.1), without a folder dialog and without a
 * storage permission (MediaStore, Android 10+). The files stay when GymLog is uninstalled. Before
 * Android 10 the app's own download folder.
 */
object DownloadsFolder {
    const val CHANNEL = "de.gymlog.app/files"

    /** Saves [bytes] as [name]; returns where it lies, as the user sees it. */
    fun save(context: Context, name: String, mimeType: String, bytes: ByteArray): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val dir = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                ?: throw IllegalStateException("no storage")
            val file = File(dir, name)
            file.writeBytes(bytes)
            return file.absolutePath
        }
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            put(MediaStore.Downloads.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/${ApkDownloads.FOLDER}")
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("insert failed")
        try {
            resolver.openOutputStream(uri)?.use { it.write(bytes) } ?: throw IllegalStateException("no stream")
            resolver.update(uri, ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) }, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
        // Android may have added " (1)" to the name.
        val saved = resolver.query(uri, arrayOf(MediaStore.Downloads.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) it.getString(0) else null
        } ?: name
        return "${Environment.DIRECTORY_DOWNLOADS}/${ApkDownloads.FOLDER}/$saved"
    }
}
