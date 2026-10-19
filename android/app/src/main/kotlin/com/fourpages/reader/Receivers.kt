package com.fourpages.reader

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Fires the daily "continue reading" reminder, then arms tomorrow's. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        SystemChannel.postReminder(context)
        SystemChannel.scheduleNext(context)
    }
}

/** Alarms are cleared on reboot/app update; re-arm the reminder. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        SystemChannel.scheduleNext(context)
        ContinueReadingWidget.updateAll(context)
    }
}
