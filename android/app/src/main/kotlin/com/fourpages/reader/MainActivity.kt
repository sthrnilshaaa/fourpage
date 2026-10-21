package com.fourpages.reader

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

/**
 * Exposes storage access to Dart for folder scanning.
 *
 * EPUBs are not media files, so on Android 11+ a directory picked with the
 * system folder picker lists as empty to dart:io unless the app holds
 * "All files access" (MANAGE_EXTERNAL_STORAGE), which can only be granted
 * from its Settings screen. Older Android versions need READ_EXTERNAL_STORAGE.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "fourpages/storage"
    private val legacyRequestCode = 4101

    private var systemChannel: SystemChannel? = null
    private var appUpdater: AppUpdater? = null
    private var flavorChannels: FlavorChannels? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerPdfChannel(flutterEngine)
        systemChannel = SystemChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        EpubUnpacker(flutterEngine.dartExecutor.binaryMessenger)
        NativeReaderChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        appUpdater = AppUpdater(this, flutterEngine.dartExecutor.binaryMessenger)
        flavorChannels = FlavorChannels(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
                "requestAllFilesAccess" -> {
                    requestAllFilesAccess()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // --- PDF (android.graphics.pdf.PdfRenderer) ------------------------------
    // Pages are rendered off the UI thread to PNG at the width Dart asks for.
    // PdfRenderer allows one open page at a time per document, so all work
    // for a document goes through one single-threaded executor.
    private val pdfExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pdfDocs = HashMap<Int, PdfRenderer>()
    private var nextPdfId = 1

    private fun registerPdfChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fourpages/pdf").setMethodCallHandler { call, result ->
            fun reply(block: () -> Any?) = pdfExecutor.execute {
                try {
                    val value = block()
                    mainHandler.post { result.success(value) }
                } catch (e: Exception) {
                    mainHandler.post { result.error("pdf", e.message, null) }
                }
            }
            when (call.method) {
                "open" -> reply {
                    val path = call.argument<String>("path")!!
                    val renderer = PdfRenderer(ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY))
                    val id = nextPdfId++
                    pdfDocs[id] = renderer
                    val sizes = ArrayList<Double>()
                    for (i in 0 until renderer.pageCount) {
                        renderer.openPage(i).use { page -> sizes.add(page.width.toDouble() / page.height.toDouble()) }
                    }
                    mapOf("id" to id, "pageCount" to renderer.pageCount, "aspectRatios" to sizes)
                }
                "render" -> reply {
                    val renderer = pdfDocs[call.argument<Int>("id")!!] ?: throw IllegalStateException("closed")
                    val index = call.argument<Int>("page")!!
                    val width = call.argument<Int>("width")!!.coerceIn(64, 3000)
                    renderer.openPage(index).use { page ->
                        val height = (width.toDouble() * page.height / page.width).toInt().coerceAtLeast(1)
                        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        bitmap.eraseColor(Color.WHITE) // PDFs assume a white page
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        val out = ByteArrayOutputStream()
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                        bitmap.recycle()
                        out.toByteArray()
                    }
                }
                "close" -> reply {
                    pdfDocs.remove(call.argument<Int>("id")!!)?.close()
                    null
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasAllFilesAccess(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }

    private fun requestAllFilesAccess() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val appSpecific = Intent(
                Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                Uri.parse("package:$packageName"),
            )
            try {
                startActivity(appSpecific)
            } catch (e: Exception) {
                // Some OEM builds lack the per-app screen; fall back to the list.
                startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
            }
        } else {
            requestPermissions(arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE), legacyRequestCode)
        }
    }

    @Deprecated("Needed for the ringtone picker result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (systemChannel?.onActivityResult(requestCode, resultCode, data) == true) return
        if (appUpdater?.onActivityResult(requestCode, resultCode) == true) return
        if (flavorChannels?.onActivityResult(requestCode, resultCode, data) == true) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        systemChannel?.onNewIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        appUpdater?.onResume()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (systemChannel?.onRequestPermissionsResult(requestCode, grantResults) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
