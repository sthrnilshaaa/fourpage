package com.fourpages.reader

import android.app.Activity
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * `fourpages/app_update`, Play Store build: Google Play's in-app update
 * (immediate flow - Play shows its own full-screen update UI). The GitHub
 * build has its own AppUpdater (src/github).
 */
class AppUpdater(private val activity: Activity, messenger: BinaryMessenger) {
    companion object {
        private const val UPDATE_REQUEST = 4301
    }

    private val manager: AppUpdateManager = AppUpdateManagerFactory.create(activity)
    private var pending: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, "fourpages/app_update").setMethodCallHandler { call, result ->
            when (call.method) {
                "info" -> result.success(appInfo(activity))
                "check" -> manager.appUpdateInfo
                    .addOnSuccessListener { info ->
                        result.success(
                            mapOf(
                                "available" to (info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE &&
                                    info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)),
                                "availableVersionCode" to info.availableVersionCode(),
                            ),
                        )
                    }
                    .addOnFailureListener { e -> result.error("check", e.message, null) }
                "start" -> manager.appUpdateInfo
                    .addOnSuccessListener { info ->
                        if (startFlow(info)) {
                            pending = result
                        } else {
                            result.success(false)
                        }
                    }
                    .addOnFailureListener { e -> result.error("start", e.message, null) }
                else -> result.notImplemented()
            }
        }
    }

    private fun startFlow(info: AppUpdateInfo): Boolean {
        val ok = info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE ||
            info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
        if (!ok || !info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)) return false
        @Suppress("DEPRECATION")
        return manager.startUpdateFlowForResult(
            info,
            activity,
            AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build(),
            UPDATE_REQUEST,
        )
    }

    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != UPDATE_REQUEST) return false
        pending?.success(resultCode == Activity.RESULT_OK)
        pending = null
        return true
    }

    /** An immediate update left half-way (app was backgrounded): resume it. */
    fun onResume() {
        manager.appUpdateInfo.addOnSuccessListener { info ->
            if (info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS) {
                startFlow(info)
            }
        }
    }
}
