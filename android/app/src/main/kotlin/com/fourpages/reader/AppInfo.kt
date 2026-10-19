package com.fourpages.reader

import android.content.Context
import android.os.Build

/** Version and flavor details for the `info` call of `fourpages/app_update`. */
fun appInfo(context: Context): Map<String, Any?> {
    val pkg = context.packageManager.getPackageInfo(context.packageName, 0)
    @Suppress("DEPRECATION")
    val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) pkg.longVersionCode else pkg.versionCode.toLong()
    return mapOf(
        "flavor" to BuildConfig.FLAVOR,
        "versionName" to pkg.versionName,
        "versionCode" to code,
        "abis" to Build.SUPPORTED_ABIS.toList(),
    )
}
