package com.fourpages.reader

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

/**
 * Home-screen widget: the book being read, its author and progress. Data is
 * written by the app (SystemChannel "updateContinueReading") whenever a
 * reading session ends; tapping opens Fourpages.
 */
class ContinueReadingWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { manager.updateAppWidget(it, views(context)) }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, ContinueReadingWidget::class.java))
            if (ids.isNotEmpty()) ids.forEach { manager.updateAppWidget(it, views(context)) }
        }

        private fun views(context: Context): RemoteViews {
            val prefs = context.getSharedPreferences(SystemChannel.PREFS, Context.MODE_PRIVATE)
            val title = prefs.getString("bookTitle", null)
            val views = RemoteViews(context.packageName, R.layout.widget_continue_reading)
            if (title == null) {
                views.setTextViewText(R.id.widget_title, context.getString(R.string.widget_empty_title))
                views.setViewVisibility(R.id.widget_subtitle, View.GONE)
                views.setViewVisibility(R.id.widget_progress_row, View.GONE)
            } else {
                val percent = prefs.getInt("bookPercent", 0)
                views.setTextViewText(R.id.widget_title, title)
                views.setTextViewText(R.id.widget_subtitle, prefs.getString("bookSubtitle", ""))
                views.setViewVisibility(R.id.widget_subtitle, View.VISIBLE)
                views.setViewVisibility(R.id.widget_progress_row, View.VISIBLE)
                views.setProgressBar(R.id.widget_progress, 100, percent, false)
                views.setTextViewText(R.id.widget_percent, "$percent%")
            }
            val open = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, open)
            return views
        }
    }
}
