package com.fourpages.reader

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger

/** Play build: channels that only this build has (see src/github for the other build). */
class FlavorChannels(activity: Activity, messenger: BinaryMessenger) {
    private val folderTree = FolderTree(activity, messenger)

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean =
        folderTree.onActivityResult(requestCode, resultCode, data)
}
