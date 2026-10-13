package com.lumioapps.paperwise

import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Lets other apps open PDFs with Paperwise. The PDF is copied into the app's
 * cache folder, and its path is sent to the Flutter side.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.lumioapps.paperwise/open"
    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel = methodChannel
        methodChannel.setMethodCallHandler { call, result ->
            if (call.method == "getInitialPdf") {
                val uri = takePdfUri(intent)
                if (uri == null) {
                    result.success(null)
                } else {
                    copyToCache(uri) { path -> result.success(path) }
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uri = takePdfUri(intent) ?: return
        copyToCache(uri) { path ->
            if (path != null) channel?.invokeMethod("pdfOpened", path)
        }
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }

    /** Returns the PDF address from a "view" intent and marks the intent as used. */
    private fun takePdfUri(intent: Intent?): Uri? {
        if (intent == null || intent.action != Intent.ACTION_VIEW) return null
        val uri = intent.data ?: return null
        intent.data = null
        return uri
    }

    private fun copyToCache(uri: Uri, done: (String?) -> Unit) {
        worker.execute {
            val path = try {
                copyUri(uri)
            } catch (e: Exception) {
                null
            }
            mainHandler.post { done(path) }
        }
    }

    private fun copyUri(uri: Uri): String? {
        val folder = File(cacheDir, "opened")
        if (!folder.exists()) folder.mkdirs()

        var name = displayName(uri) ?: uri.lastPathSegment ?: "document.pdf"
        name = name.substringAfterLast('/')
            .replace(Regex("[\\\\/:*?\"<>|]"), "_")
            .trim()
        if (name.isEmpty()) name = "document.pdf"
        if (!name.lowercase().endsWith(".pdf")) name += ".pdf"

        val target = File(folder, name)
        val input = contentResolver.openInputStream(uri) ?: return null
        input.use { source ->
            target.outputStream().use { sink -> source.copyTo(sink) }
        }
        return target.absolutePath
    }

    private fun displayName(uri: Uri): String? {
        if (uri.scheme != "content") return null
        return try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
        } catch (e: Exception) {
            null
        }
    }
}
