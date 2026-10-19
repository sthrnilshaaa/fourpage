package com.fourpages.reader

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * `fourpages/app_update`, GitHub build. Dart finds the newest GitHub release
 * and downloads its APK into cacheDir/updates; this hands that file to the
 * system installer. The Play build has its own AppUpdater (src/playstore).
 */
class AppUpdater(private val activity: Activity, messenger: BinaryMessenger) {
    init {
        MethodChannel(messenger, "fourpages/app_update").setMethodCallHandler { call, result ->
            when (call.method) {
                "info" -> result.success(appInfo(activity))
                "canInstall" -> result.success(canInstall())
                "openInstallSettings" -> {
                    openInstallSettings()
                    result.success(null)
                }
                "install" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("args", "path missing", null)
                    } else if (!canInstall()) {
                        result.success("needs_permission")
                    } else {
                        try {
                            install(File(path))
                            result.success("started")
                        } catch (e: Exception) {
                            result.error("install", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || activity.packageManager.canRequestPackageInstalls()

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity.startActivity(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}")),
            )
        }
    }

    private fun install(apk: File) {
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", apk)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        activity.startActivity(intent)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean = false

    fun onResume() {}
}
