package com.audionotes.audio_notes.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.RemoteViews
import com.audionotes.audio_notes.MainActivity
import com.audionotes.audio_notes.R

class QuickRecordWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            appWidgetManager.updateAppWidget(
                appWidgetId,
                buildRemoteViews(context, options, appWidgetId),
            )
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        appWidgetManager.updateAppWidget(
            appWidgetId,
            buildRemoteViews(context, newOptions, appWidgetId),
        )
    }

    override fun onEnabled(context: Context) {
        updateAll(context)
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, QuickRecordWidgetProvider::class.java)
            val appWidgetIds = manager.getAppWidgetIds(component)
            if (appWidgetIds.isEmpty()) {
                return
            }

            appWidgetIds.forEach { appWidgetId ->
                manager.updateAppWidget(
                    appWidgetId,
                    buildRemoteViews(context, manager.getAppWidgetOptions(appWidgetId), appWidgetId),
                )
            }
        }

        private fun buildRemoteViews(context: Context, options: Bundle?, appWidgetId: Int): RemoteViews {
            val layout = layoutFor(options)
            val views = RemoteViews(context.packageName, layout)
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                launchIntent(context),
                pendingIntentFlags(),
            )

            views.setOnClickPendingIntent(R.id.quick_record_root, pendingIntent)
            if (layout != R.layout.widget_quick_record_compact) {
                views.setTextViewText(R.id.quick_record_title, "快速录音")
                views.setTextViewText(R.id.quick_record_subtitle, "点击开始录音")
                views.setTextViewText(R.id.quick_record_hint, "")
            }
            return views
        }

        private fun layoutFor(options: Bundle?): Int {
            val minWidth = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0
            val minHeight = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 0

            return when {
                minWidth < 180 || minHeight < 180 -> R.layout.widget_quick_record_compact
                minWidth < 260 || minHeight < 260 -> R.layout.widget_quick_record
                else -> R.layout.widget_quick_record_expanded
            }
        }

        private fun launchIntent(context: Context): Intent {
            return Intent(context, MainActivity::class.java).apply {
                action = "com.audionotes.audio_notes.RECORD_AUDIO"
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addCategory(Intent.CATEGORY_DEFAULT)
            }
        }

        private fun pendingIntentFlags(): Int {
            return PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        }
    }
}