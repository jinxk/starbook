package com.jinxk.starbook

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    // One byte over the limit lets Dart tell a file at the limit from a larger one.
    private val limit = 50 * 1024 * 1024 + 1

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "starbook/open")
            .setMethodCallHandler { call, result ->
                if (call.method != "take") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val uri = fileUri(intent)
                intent = Intent()
                if (uri == null) {
                    result.success(null)
                    return@setMethodCallHandler
                }
                Thread {
                    val bytes = read(uri)
                    val name = nameOf(uri)
                    runOnUiThread {
                        result.success(mapOf("name" to name, "bytes" to bytes))
                    }
                }.start()
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    private fun fileUri(intent: Intent): Uri? = when (intent.action) {
        Intent.ACTION_VIEW -> intent.data
        Intent.ACTION_SEND ->
            if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
        else -> null
    }

    private fun nameOf(uri: Uri): String {
        val shown = runCatching {
            contentResolver
                .query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { if (it.moveToFirst()) it.getString(0) else null }
        }.getOrNull()
        return shown ?: uri.lastPathSegment ?: ""
    }

    private fun read(uri: Uri): ByteArray = try {
        val out = ByteArrayOutputStream()
        contentResolver.openInputStream(uri)?.use { input ->
            val buffer = ByteArray(64 * 1024)
            while (out.size() < limit) {
                val n = input.read(buffer, 0, minOf(buffer.size, limit - out.size()))
                if (n < 0) break
                out.write(buffer, 0, n)
            }
        }
        out.toByteArray()
    } catch (e: Exception) {
        ByteArray(0)
    }
}
