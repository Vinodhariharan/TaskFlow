package com.taskflow.taskflow

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home screen widget showing today's outstanding tasks.
 *
 * All the strings are computed in Dart (see WidgetService) and read straight
 * out of shared storage here, so this stays a dumb renderer — there's no
 * duplicate task logic on the native side to drift out of sync.
 */
class TaskWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.task_widget).apply {
                setTextViewText(
                    R.id.task_count,
                    widgetData.getString("task_count", null) ?: "Tasks",
                )
                setTextViewText(
                    R.id.task_progress,
                    widgetData.getString("task_progress", null) ?: "Open TaskFlow",
                )

                // Fixed number of rows; blank ones are hidden rather than
                // showing empty space.
                val rows = intArrayOf(R.id.task_0, R.id.task_1, R.id.task_2)
                rows.forEachIndexed { index, viewId ->
                    val title = widgetData.getString("task_$index", null).orEmpty()
                    if (title.isBlank()) {
                        setViewVisibility(viewId, android.view.View.GONE)
                    } else {
                        setViewVisibility(viewId, android.view.View.VISIBLE)
                        setTextViewText(viewId, "•  $title")
                    }
                }

                // Tapping anywhere opens the app on the Tasks tab.
                setOnClickPendingIntent(
                    R.id.task_widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("taskflow://tasks"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
