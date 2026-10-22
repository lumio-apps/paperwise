package com.lumioapps.paperwise

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Lets other apps hand files to Paperwise: "Open with" for a PDF, and the
 * Share menu for PDFs and pictures. Each file is copied into the app's cache
 * folder, and the paths are sent to the Flutter side.
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
            if (call.method == "getInitialFiles") {
                val uris = takeUris(intent)
                if (uris.isEmpty()) {
                    result.success(null)
                } else {
                    copyToCache(uris) { paths -> result.success(paths) }
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uris = takeUris(intent)
        if (uris.isEmpty()) return
        copyToCache(uris) { paths ->
            if (paths.isNotEmpty()) channel?.invokeMethod("filesOpened", paths)
        }
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }

    /** Returns the addresses of the files in a "view" or "share" intent and marks the intent as used. */
    private fun takeUris(intent: Intent?): List<Uri> {
        if (intent == null) return emptyList()
        val found = ArrayList<Uri>()
        when (intent.action) {
            Intent.ACTION_VIEW -> {
                intent.data?.let { found.add(it) }
                intent.data = null
            }
            Intent.ACTION_SEND -> {
                singleStream(intent)?.let { found.add(it) }
                intent.removeExtra(Intent.EXTRA_STREAM)
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                found.addAll(manyStreams(intent))
                intent.removeExtra(Intent.EXTRA_STREAM)
            }
        }
        if (found.isNotEmpty()) intent.action = null
        return found
    }

    @Suppress("DEPRECATION")
    private fun singleStream(intent: Intent): Uri? {
        return if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        }
    }

    @Suppress("DEPRECATION")
    private fun manyStreams(intent: Intent): List<Uri> {
        val list: ArrayList<Uri>? = if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
        }
        return list ?: emptyList()
    }

    private fun copyToCache(uris: List<Uri>, done: (List<String>) -> Unit) {
        worker.execute {
            val paths = ArrayList<String>()
            for ((index, uri) in uris.withIndex()) {
                try {
                    copyUri(uri, if (uris.size > 1) index + 1 else 0)?.let { paths.add(it) }
                } catch (e: Exception) {
                    // Skip a file that cannot be read.
                }
            }
            mainHandler.post { done(paths) }
        }
    }

    private fun copyUri(uri: Uri, number: Int): String? {
        val folder = File(cacheDir, "opened")
        if (!folder.exists()) folder.mkdirs()

        var name = displayName(uri) ?: uri.lastPathSegment ?: "document"
        name = name.substringAfterLast('/')
            .replace(Regex("[\\\\/:*?\"<>|]"), "_")
            .trim()
        if (name.isEmpty()) name = "document"
        if (!Regex(".*\\.(pdf|jpe?g|png|webp|gif|bmp|heic|heif)$", RegexOption.IGNORE_CASE).matches(name)) {
            val type = contentResolver.getType(uri) ?: ""
            name += when {
                type == "image/png" -> ".png"
                type == "image/webp" -> ".webp"
                type == "image/gif" -> ".gif"
                type == "image/bmp" -> ".bmp"
                type.startsWith("image/") -> ".jpg"
                else -> ".pdf"
            }
        }
        // Several files can share a name (for example image.jpg from a chat app).
        if (number > 0) name = "${number}_$name"

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
