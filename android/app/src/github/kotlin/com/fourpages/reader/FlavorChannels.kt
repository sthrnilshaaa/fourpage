package com.fourpages.reader

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger

/** GitHub build: no extra channels (the Play build adds its folder picker here). */
@Suppress("UNUSED_PARAMETER")
class FlavorChannels(activity: Activity, messenger: BinaryMessenger) {
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean = false
}
