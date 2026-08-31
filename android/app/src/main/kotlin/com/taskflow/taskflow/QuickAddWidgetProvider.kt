package com.taskflow.taskflow

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * A small two-button widget for capture only: one tap to start a new task,
 * one to log a new expense. Shows no data, so unlike the other two it never
 * needs refreshing — it's purely a pair of shortcuts for the case where the
 * point is to write something down before you forget it.
 */
class QuickAddWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.quick_add_widget).apply {
                setOnClickPendingIntent(
                    R.id.quick_add_task,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("taskflow://addtask"),
                    ),
                )
                setOnClickPendingIntent(
                    R.id.quick_add_expense,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("taskflow://addexpense"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
