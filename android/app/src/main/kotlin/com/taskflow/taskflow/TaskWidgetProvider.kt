package com.taskflow.taskflow

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home screen widget showing today's outstanding tasks, scrollable through
 * all of them.
 *
 * All the strings are computed in Dart (see WidgetService) and read straight
 * out of shared storage here, so this stays a dumb renderer — there's no
 * duplicate task logic on the native side to drift out of sync. The rows
 * themselves come from TaskWidgetService.
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

                // Each widget needs an adapter intent the system considers
                // distinct, or two placed widgets share one factory. The data
                // URI is what makes them differ — extras alone are ignored
                // when the system compares them.
                val adapterIntent = Intent(context, TaskWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                setRemoteAdapter(R.id.task_list, adapterIntent)
                setEmptyView(R.id.task_list, R.id.task_empty)

                // Rows in a collection can't each carry their own
                // PendingIntent; they fill in this one template. It has to be
                // mutable for that, which rules out
                // HomeWidgetBackgroundIntent.getBroadcast — it builds an
                // immutable one — so the equivalent is built by hand here.
                setPendingIntentTemplate(R.id.task_list, backgroundTemplate(context))

                // The header opens the app on the Tasks tab. Not the root:
                // a click handler on the widget root swallows taps meant for
                // the list rows underneath it.
                setOnClickPendingIntent(
                    R.id.task_header,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("taskflow://tasks"),
                    ),
                )
                setOnClickPendingIntent(
                    R.id.task_empty,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("taskflow://tasks"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
            // updateAppWidget redraws the frame but not the collection; the
            // factory only re-reads storage when told to.
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.task_list)
        }
    }

    /**
     * A mutable broadcast to home_widget's background receiver, which each
     * row completes with its own `taskflow://toggle?id=…`. Ticking therefore
     * runs Dart in the background and never brings the app to the front.
     *
     * The action string is home_widget's own, duplicated because the plugin
     * keeps its constant private; the receiver ignores intents without it.
     */
    private fun backgroundTemplate(context: Context): PendingIntent {
        val intent = Intent(context, BACKGROUND_RECEIVER).apply {
            action = HOME_WIDGET_BACKGROUND_ACTION
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = flags or PendingIntent.FLAG_MUTABLE
        }
        return PendingIntent.getBroadcast(context, 0, intent, flags)
    }

    private companion object {
        const val HOME_WIDGET_BACKGROUND_ACTION =
            "es.antonborri.home_widget.action.BACKGROUND"
        val BACKGROUND_RECEIVER =
            es.antonborri.home_widget.HomeWidgetBackgroundReceiver::class.java
    }
}
