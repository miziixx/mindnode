package com.thoughtgraph.app.exportimport

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File

/** Real file read/write/share backing the export & import features. */
object FileOps {

    fun writeToUri(context: Context, uri: Uri, content: String): Boolean = try {
        context.contentResolver.openOutputStream(uri)?.use { out ->
            out.write(content.toByteArray(Charsets.UTF_8))
        } ?: return false
        true
    } catch (e: Exception) {
        false
    }

    fun readFromUri(context: Context, uri: Uri): String? = try {
        context.contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }
    } catch (e: Exception) {
        null
    }

    /** Writes [content] to a cache file and returns a shareable content URI. */
    fun shareText(context: Context, filename: String, mime: String, content: String) {
        val dir = File(context.cacheDir, "shared").apply { mkdirs() }
        val file = File(dir, filename)
        file.writeText(content, Charsets.UTF_8)
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(intent, "공유").apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        })
    }
}
