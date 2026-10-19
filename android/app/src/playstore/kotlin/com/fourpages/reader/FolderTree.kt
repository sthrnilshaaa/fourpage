package com.fourpages.reader

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * `fourpages/folder_tree`, Play build: folder scans through the system
 * folder picker (Storage Access Framework) instead of "All files access".
 * The picked folder's read permission is kept, so "Scan again" works later.
 */
class FolderTree(private val activity: Activity, messenger: BinaryMessenger) {
    companion object {
        private const val PICK_REQUEST = 4401
    }

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pendingPick: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, "fourpages/folder_tree").setMethodCallHandler { call, result ->
            fun background(block: () -> Any?) = io.execute {
                try {
                    val value = block()
                    main.post { result.success(value) }
                } catch (e: SecurityException) {
                    main.post { result.error("no_permission", e.message, null) }
                } catch (e: Exception) {
                    main.post { result.error("folder_tree", e.message, null) }
                }
            }
            when (call.method) {
                "pick" -> pick(result)
                "list" -> background {
                    val extensions = call.argument<List<String>>("extensions")!!.map { it.lowercase() }.toSet()
                    list(Uri.parse(call.argument<String>("uri")!!), extensions)
                }
                "read" -> background {
                    val uri = Uri.parse(call.argument<String>("uri")!!)
                    activity.contentResolver.openInputStream(uri)!!.use { it.readBytes() }
                }
                "hasAccess" -> result.success(hasAccess(call.argument<String>("uri")!!))
                "release" -> {
                    try {
                        activity.contentResolver.releasePersistableUriPermission(
                            Uri.parse(call.argument<String>("uri")!!),
                            Intent.FLAG_GRANT_READ_URI_PERMISSION,
                        )
                    } catch (_: SecurityException) {
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun pick(result: MethodChannel.Result) {
        pendingPick?.success(null)
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
        )
        try {
            activity.startActivityForResult(intent, PICK_REQUEST)
        } catch (e: Exception) {
            pendingPick = null
            result.error("folder_tree", e.message, null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_REQUEST) return false
        val result = pendingPick ?: return true
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        try {
            activity.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (_: SecurityException) {
            // Still readable for this session.
        }
        result.success(uri.toString())
        return true
    }

    private fun hasAccess(uri: String): Boolean =
        activity.contentResolver.persistedUriPermissions.any { it.uri.toString() == uri && it.isReadPermission }

    /** Every file under [tree] (recursively) whose extension is in [extensions]. */
    private fun list(tree: Uri, extensions: Set<String>): List<Map<String, String>> {
        val found = ArrayList<Map<String, String>>()
        val queue = ArrayDeque<String>()
        queue.add(DocumentsContract.getTreeDocumentId(tree))
        val columns = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        while (queue.isNotEmpty()) {
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, queue.removeFirst())
            activity.contentResolver.query(children, columns, null, null, null)?.use { c ->
                while (c.moveToNext()) {
                    val id = c.getString(0) ?: continue
                    val name = c.getString(1) ?: continue
                    if (c.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) {
                        if (!name.startsWith(".")) queue.add(id)
                    } else if (name.substringAfterLast('.', "").lowercase() in extensions) {
                        found.add(
                            mapOf(
                                "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, id).toString(),
                                "name" to name,
                            ),
                        )
                    }
                }
            }
        }
        return found
    }
}
