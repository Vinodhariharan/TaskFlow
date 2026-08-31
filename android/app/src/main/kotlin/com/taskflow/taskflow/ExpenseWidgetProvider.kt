package com.taskflow.taskflow

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home screen widget showing spending so far this month, with the trailing
 * 30 days underneath. Amounts arrive pre-formatted in the user's chosen
 * currency from Dart, so currency handling lives in exactly one place.
 */
class ExpenseWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.expense_widget).apply {
                setTextViewText(
                    R.id.expense_month,
                    widgetData.getString("expense_month", null) ?: "—",
                )
                setTextViewText(
                    R.id.expense_30d,
                    widgetData.getString("expense_30d", null)?.let { "$it in the last 30 days" }
                        ?: "Open TaskFlow",
                )

                // "+" opens the app's add-expense sheet — a widget can't
                // take an amount as input, so it hands over to the app.
                setOnClickPendingIntent(
                    R.id.expense_add,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("taskflow://addexpense"),
                    ),
                )

                // Tapping anywhere else opens the app on the Expenses tab.
                setOnClickPendingIntent(
                    R.id.expense_widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("taskflow://expenses"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
