package com.taskflow.taskflow

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home screen widget showing today's outstanding tasks.
 *
 * All the strings are computed in Dart (see WidgetService) and read straight
 * out of shared storage here, so this stays a dumb renderer — there's no
 * duplicate task logic on the native side to drift out of sync.
 *
 * Two kinds of tap: the tick button next to a task completes it in place via
 * a background broadcast (no app launch), everything else opens the app.
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

                // Header "+" adds a task. A widget can't take text input, so
                // this opens the app's new-task page rather than trying to
                // capture a title in place.
                setOnClickPendingIntent(
                    R.id.task_add,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("taskflow://addtask"),
                    ),
                )

                // Fixed number of rows; blank ones are hidden rather than
                // showing empty space.
                val rows = arrayOf(
                    Triple(R.id.task_row_0, R.id.task_0, R.id.task_check_0),
                    Triple(R.id.task_row_1, R.id.task_1, R.id.task_check_1),
                    Triple(R.id.task_row_2, R.id.task_2, R.id.task_check_2),
                )
                rows.forEachIndexed { index, (rowId, labelId, checkId) ->
                    val title = widgetData.getString("task_$index", null).orEmpty()
                    val id = widgetData.getString("task_${index}_id", null).orEmpty()
                    if (title.isBlank()) {
                        setViewVisibility(rowId, View.GONE)
                    } else {
                        setViewVisibility(rowId, View.VISIBLE)
                        setTextViewText(labelId, title)

                        // Ticking runs Dart in the background and re-renders
                        // the widget; the app is never brought to the front.
                        setOnClickPendingIntent(
                            checkId,
                            HomeWidgetBackgroundIntent.getBroadcast(
                                context,
                                Uri.parse("taskflow://toggle?id=$id"),
                            ),
                        )
                        // Tapping the title opens that task's page.
                        setOnClickPendingIntent(
                            labelId,
                            HomeWidgetLaunchIntent.getActivity(
                                context,
                                MainActivity::class.java,
                                Uri.parse("taskflow://task?id=$id"),
                            ),
                        )
                    }
                }

                // Anywhere not covered by a more specific target above — the
                // header text, the empty space below the rows — opens the app
                // on the Tasks tab. Child handlers take precedence, so the
                // "+" and the tick buttons still win where they overlap.
                val openTasks = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("taskflow://tasks"),
                )
                setOnClickPendingIntent(R.id.task_header, openTasks)
                setOnClickPendingIntent(R.id.task_widget_root, openTasks)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
