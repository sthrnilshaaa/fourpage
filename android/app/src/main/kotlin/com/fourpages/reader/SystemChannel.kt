package com.fourpages.reader

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

/**
 * `fourpages/system`: notifications + daily reminder, the notification-sound
 * picker, the "Continue reading" widget data, and opening links. Built on
 * Android APIs directly (no plugins).
 */
class SystemChannel(private val activity: Activity, messenger: BinaryMessenger) {
    companion object {
        const val PREFS = "fourpages_system"
        const val SOUND_PICK_REQUEST = 4201
        const val NOTIFICATION_PERMISSION_REQUEST = 4202
        private const val REMINDER_ID = 1001
        private const val BREAK_ID = 1002
        private const val UPDATE_ID = 1003
        private const val UPDATES_CHANNEL = "app_updates"

        /** Intent extra on the update notification; read by Dart via takeLaunchAction. */
        const val EXTRA_ACTION = "fourpage_action"

        /** One channel per sound: a channel's sound can't change after creation. */
        fun channelFor(context: Context, sound: String): String {
            val id = "reminders_" + Integer.toHexString(sound.hashCode())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val manager = context.getSystemService(NotificationManager::class.java)
                if (manager.getNotificationChannel(id) == null) {
                    val channel = NotificationChannel(id, "Reading reminders", NotificationManager.IMPORTANCE_DEFAULT)
                    val attrs = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build()
                    when (sound) {
                        "silent" -> channel.setSound(null, null)
                        "default" -> channel.setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION), attrs)
                        else -> channel.setSound(Uri.parse(sound), attrs)
                    }
                    manager.createNotificationChannel(channel)
                }
            }
            return id
        }

        fun post(context: Context, id: Int, title: String, body: String, sound: String) {
            val open = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val builder = NotificationCompat.Builder(context, channelFor(context, sound))
                .setSmallIcon(R.drawable.ic_stat_book)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setContentIntent(open)
                .setAutoCancel(true)
            if (sound == "silent") builder.setSilent(true)
            try {
                NotificationManagerCompat.from(context).notify(id, builder.build())
            } catch (e: SecurityException) {
                // Notification permission revoked - nothing to show.
            }
        }

        /** Schedules the next daily reminder (re-armed by ReminderReceiver each time). */
        fun scheduleNext(context: Context) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val minutes = prefs.getInt("reminderMinutes", -1)
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pending = reminderIntent(context)
            alarm.cancel(pending)
            if (minutes < 0) return
            val next = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, minutes / 60)
                set(Calendar.MINUTE, minutes % 60)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
            }
            // Inexact on purpose: no exact-alarm permission needed, and a few
            // minutes either way is fine for a reading reminder.
            alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.timeInMillis, pending)
        }

        fun reminderIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
            context, REMINDER_ID, Intent(context, ReminderReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        fun postReminder(context: Context) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val title = prefs.getString("reminderTitle", null) ?: return // nothing read yet
            val body = prefs.getString("reminderBody", "") ?: ""
            post(context, REMINDER_ID, title, body, prefs.getString("sound", "default") ?: "default")
        }
    }

    /** Set when the app was opened from one of our notifications (e.g. "update"). */
    private var launchAction: String? = activity.intent?.getStringExtra(EXTRA_ACTION)

    fun onNewIntent(intent: Intent) {
        intent.getStringExtra(EXTRA_ACTION)?.let { launchAction = it }
    }

    /** "Update available": own channel, opens the app with the update action. */
    private fun postUpdate(title: String, body: String, channelName: String): Boolean {
        val manager = NotificationManagerCompat.from(context)
        if (!manager.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val system = context.getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(UPDATES_CHANNEL, channelName, NotificationManager.IMPORTANCE_DEFAULT)
            system.createNotificationChannel(channel) // updates the name if it changed
            if (system.getNotificationChannel(UPDATES_CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE) return false
        }
        val open = PendingIntent.getActivity(
            context, UPDATE_ID,
            Intent(context, MainActivity::class.java)
                .putExtra(EXTRA_ACTION, "update")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, UPDATES_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_book)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(open)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .build()
        return try {
            manager.notify(UPDATE_ID, notification)
            true
        } catch (e: SecurityException) {
            false
        }
    }

    private var pendingSoundResult: MethodChannel.Result? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val context: Context get() = activity.applicationContext

    init {
        MethodChannel(messenger, "fourpages/system").setMethodCallHandler { call, result ->
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            when (call.method) {
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT < 33 ||
                        activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success(NotificationManagerCompat.from(context).areNotificationsEnabled())
                    } else {
                        pendingPermissionResult = result
                        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION_REQUEST)
                    }
                }
                "scheduleDailyReminder" -> {
                    prefs.edit()
                        .putInt("reminderMinutes", call.argument<Int>("minutes") ?: -1)
                        .putString("sound", call.argument<String>("sound") ?: "default")
                        .apply()
                    scheduleNext(context)
                    result.success(null)
                }
                "cancelDailyReminder" -> {
                    prefs.edit().putInt("reminderMinutes", -1).apply()
                    scheduleNext(context)
                    result.success(null)
                }
                "updateContinueReading" -> {
                    prefs.edit()
                        .putString("bookTitle", call.argument<String>("title"))
                        .putString("bookSubtitle", call.argument<String>("subtitle"))
                        .putInt("bookPercent", call.argument<Int>("percent") ?: 0)
                        .putString("reminderTitle", call.argument<String>("reminderTitle"))
                        .putString("reminderBody", call.argument<String>("reminderBody"))
                        .apply()
                    ContinueReadingWidget.updateAll(context)
                    result.success(null)
                }
                "notifyNow" -> {
                    post(
                        context, BREAK_ID,
                        call.argument<String>("title") ?: "", call.argument<String>("body") ?: "",
                        call.argument<String>("sound") ?: "default",
                    )
                    result.success(null)
                }
                "notifyUpdate" -> result.success(
                    postUpdate(
                        call.argument<String>("title") ?: "",
                        call.argument<String>("body") ?: "",
                        call.argument<String>("channelName") ?: "",
                    ),
                )
                "cancelUpdateNotification" -> {
                    NotificationManagerCompat.from(context).cancel(UPDATE_ID)
                    result.success(null)
                }
                "takeLaunchAction" -> {
                    result.success(launchAction)
                    launchAction = null
                }
                "pickNotificationSound" -> {
                    pendingSoundResult = result
                    val current = call.argument<String>("current")
                    val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER)
                        .putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_NOTIFICATION)
                        .putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                        .putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                    if (current != null && current.startsWith("content://")) {
                        intent.putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(current))
                    }
                    activity.startActivityForResult(intent, SOUND_PICK_REQUEST)
                }
                "openUrl" -> {
                    try {
                        activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url"))))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != SOUND_PICK_REQUEST) return false
        val result = pendingSoundResult ?: return true
        pendingSoundResult = null
        @Suppress("DEPRECATION")
        val uri: Uri? = if (resultCode == Activity.RESULT_OK) data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI) else null
        if (uri == null) {
            result.success(null)
        } else {
            val name = RingtoneManager.getRingtone(context, uri)?.getTitle(context) ?: "Custom sound"
            result.success(mapOf("uri" to uri.toString(), "name" to name))
        }
        return true
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return false
        pendingPermissionResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        pendingPermissionResult = null
        return true
    }
}
