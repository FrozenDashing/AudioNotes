package com.audionotes.audio_notes.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import com.audionotes.audio_notes.MainActivity
import com.audionotes.audio_notes.R

class TodoSummaryWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            appWidgetManager.updateAppWidget(
                appWidgetId,
                buildRemoteViews(context, options),
            )
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        appWidgetManager.updateAppWidget(
            appWidgetId,
            buildRemoteViews(context, newOptions),
        )
    }

    override fun onEnabled(context: Context) {
        updateAll(context)
    }

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val PREF_KEY = "flutter.widget.todo.summary.payload"

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, TodoSummaryWidgetProvider::class.java)
            val appWidgetIds = manager.getAppWidgetIds(component)
            if (appWidgetIds.isEmpty()) {
                return
            }

            appWidgetIds.forEach { appWidgetId ->
                manager.updateAppWidget(
                    appWidgetId,
                    buildRemoteViews(context, manager.getAppWidgetOptions(appWidgetId)),
                )
            }
        }

        private fun buildRemoteViews(context: Context, options: Bundle?): RemoteViews {
            val summary = WidgetSummaryParser.fromJson(readPayload(context))
            val views = RemoteViews(context.packageName, R.layout.widget_todo_summary)
            val pendingIntent = PendingIntent.getActivity(
                context,
                2001,
                launchIntent(context),
                pendingIntentFlags(),
            )

            views.setOnClickPendingIntent(R.id.todo_summary_root, pendingIntent)
            views.setTextViewText(R.id.todo_summary_title, summary.title)
            views.setTextViewText(R.id.todo_summary_subtitle, summary.subtitle)

            bindSection(
                views = views,
                titleViewId = R.id.section_urgent_title,
                countViewId = R.id.section_urgent_count,
                emptyViewId = R.id.section_urgent_empty,
                itemViewIds = intArrayOf(
                    R.id.section_urgent_item_1,
                    R.id.section_urgent_item_2,
                    R.id.section_urgent_item_3,
                ),
                section = summary.sections.getOrNull(0),
                accentColor = ContextCompat.getColor(context, R.color.widget_record_accent),
            )
            bindSection(
                views = views,
                titleViewId = R.id.section_high_priority_title,
                countViewId = R.id.section_high_priority_count,
                emptyViewId = R.id.section_high_priority_empty,
                itemViewIds = intArrayOf(
                    R.id.section_high_priority_item_1,
                    R.id.section_high_priority_item_2,
                    R.id.section_high_priority_item_3,
                ),
                section = summary.sections.getOrNull(1),
                accentColor = ContextCompat.getColor(context, R.color.widget_tomorrow_accent),
            )
            bindSection(
                views = views,
                titleViewId = R.id.section_this_week_title,
                countViewId = R.id.section_this_week_count,
                emptyViewId = R.id.section_this_week_empty,
                itemViewIds = intArrayOf(
                    R.id.section_this_week_item_1,
                    R.id.section_this_week_item_2,
                    R.id.section_this_week_item_3,
                ),
                section = summary.sections.getOrNull(2),
                accentColor = ContextCompat.getColor(context, R.color.widget_today_accent),
            )

            applySizeVariant(views, options)
            return views
        }

        private fun applySizeVariant(views: RemoteViews, options: Bundle?) {
            val minWidth = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0
            val minHeight = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 0

            val showHighPriority = minWidth >= 200 && minHeight >= 180
            val showThisWeek = minWidth >= 280 && minHeight >= 240

            views.setViewVisibility(R.id.section_urgent_panel, View.VISIBLE)
            views.setViewVisibility(
                R.id.section_high_priority_panel,
                if (showHighPriority) View.VISIBLE else View.GONE,
            )
            views.setViewVisibility(
                R.id.section_this_week_panel,
                if (showThisWeek && showHighPriority) View.VISIBLE else View.GONE,
            )
        }

        private fun bindSection(
            views: RemoteViews,
            titleViewId: Int,
            countViewId: Int,
            emptyViewId: Int,
            itemViewIds: IntArray,
            section: WidgetSection?,
            accentColor: Int,
        ) {
            val currentSection = section ?: WidgetSection("", 0, emptyList())
            views.setTextViewText(titleViewId, currentSection.title)
            views.setTextViewText(countViewId, currentSection.count.toString())
            views.setTextColor(titleViewId, accentColor)
            views.setTextColor(countViewId, accentColor)

            val items = currentSection.items.take(itemViewIds.size)
            if (currentSection.count <= 0 || items.isEmpty()) {
                views.setViewVisibility(emptyViewId, View.VISIBLE)
                views.setTextViewText(emptyViewId, "暂无待办")
            } else {
                views.setViewVisibility(emptyViewId, View.GONE)
            }

            itemViewIds.forEachIndexed { index, viewId ->
                val text = items.getOrNull(index)
                if (text.isNullOrBlank()) {
                    views.setViewVisibility(viewId, View.GONE)
                    views.setTextViewText(viewId, "")
                } else {
                    views.setViewVisibility(viewId, View.VISIBLE)
                    views.setTextViewText(viewId, "• $text")
                }
            }
        }

        private fun readPayload(context: Context): String? {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getString(PREF_KEY, null)
        }

        private fun launchIntent(context: Context): Intent {
            return Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
        }

        private fun pendingIntentFlags(): Int {
            return PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        }
    }
}