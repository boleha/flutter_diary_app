package com.example.diary_app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.diary_app/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveZipToDownloads" -> {
                        val path = call.argument<String>("path")
                        val fileName = call.argument<String>("fileName")
                        if (path == null || fileName == null) {
                            result.error("BAD_ARG", "path and fileName required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val saved = saveZipToDownloads(path, fileName)
                            result.success(saved)
                        } catch (e: Exception) {
                            result.error("SAVE_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveZipToDownloads(sourcePath: String, fileName: String): String {
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) throw Exception("source file not found")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+: 通过 MediaStore 写入公共下载目录，无需权限
            val resolver = applicationContext.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "application/zip")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw Exception("failed to create download entry")
            resolver.openOutputStream(uri)?.use { out ->
                FileInputStream(sourceFile).use { inp ->
                    inp.copyTo(out)
                }
            } ?: throw Exception("failed to open output stream")
        } else {
            // Android 9 及以下: 直接写入公共下载目录
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!dir.exists()) dir.mkdirs()
            val dest = File(dir, fileName)
            FileInputStream(sourceFile).use { inp ->
                FileOutputStream(dest).use { out ->
                    inp.copyTo(out)
                }
            }
        }
        return "下载/$fileName"
    }
}
