package com.octane.octane95

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException

class MainActivity : FlutterActivity() {
    private companion object {
        const val backupStorageChannel = "com.octane.octane95/backup_storage"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backupStorageChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveBackupFileToDownloads") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val sourcePath = call.argument<String>("sourcePath")
                val fileName = call.argument<String>("fileName")
                if (sourcePath.isNullOrBlank() || fileName.isNullOrBlank()) {
                    result.error("invalid_arguments", "Backup file information is missing.", null)
                    return@setMethodCallHandler
                }
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    result.error(
                        "unsupported_android_version",
                        "Saving directly to Downloads requires Android 10 or later.",
                        null,
                    )
                    return@setMethodCallHandler
                }

                try {
                    val source = File(sourcePath)
                    if (!source.isFile) throw IOException("Temporary backup file is unavailable.")

                    val values = ContentValues().apply {
                        put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                        put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
                        put(
                            MediaStore.MediaColumns.RELATIVE_PATH,
                            "${Environment.DIRECTORY_DOWNLOADS}/고급유노트",
                        )
                        put(MediaStore.MediaColumns.IS_PENDING, 1)
                    }
                    val collection = MediaStore.Downloads.getContentUri(
                        MediaStore.VOLUME_EXTERNAL_PRIMARY,
                    )
                    val uri = contentResolver.insert(collection, values)
                        ?: throw IOException("Unable to create backup file.")

                    try {
                        FileInputStream(source).use { input ->
                            contentResolver.openOutputStream(uri, "w")?.use { output ->
                                input.copyTo(output)
                            } ?: throw IOException("Unable to open backup file.")
                        }
                        values.clear()
                        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                        contentResolver.update(uri, values, null, null)
                    } catch (error: Exception) {
                        contentResolver.delete(uri, null, null)
                        throw error
                    }

                    val savedFileName = contentResolver.query(
                        uri,
                        arrayOf(MediaStore.MediaColumns.DISPLAY_NAME),
                        null,
                        null,
                        null,
                    )?.use { cursor ->
                        if (cursor.moveToFirst()) cursor.getString(0) else null
                    } ?: fileName
                    result.success("Download/고급유노트/$savedFileName")
                } catch (error: Exception) {
                    result.error("external_storage", error.message, null)
                }
            }
    }
}
