package com.taskflow.taskflow

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home screen widget for one habit, chosen per placed widget by
 * HabitWidgetConfigureActivity.
 *
 * Like the other two providers this is a dumb renderer: WidgetService in Dart
 * decides the name, the status line and even the seven-day strip, which
 * arrives as a seven-character string. Nothing here knows what a streak is,
 * so there's no second implementation of the rules to drift out of sync with
 * habit_stats.dart.
 *
 * Tapping the button logs the habit in the background; everything else opens
 * the habit's page in the app.
 */
class HabitWidgetProvider : HomeWidgetProvider() {

    private companion object {
        /** Character codes shared with WidgetService.habitWeekStrip in Dart. */
        const val DAY_DONE = 'd'
        const val DAY_OPEN = 'o'
        const val DAY_MISSED = 'm'
        const val WEEK_DAYS = 7

        val DAY_VIEW_IDS = intArrayOf(
            R.id.habit_day_0,
            R.id.habit_day_1,
            R.id.habit_day_2,
            R.id.habit_day_3,
            R.id.habit_day_4,
            R.id.habit_day_5,
            R.id.habit_day_6,
        )
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            appWidgetManager.updateAppWidget(
                widgetId,
                buildViews(context, widgetId, widgetData),
            )
        }
    }

    /** Forgets which habit a removed widget tracked. */
    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val editor = HomeWidgetPlugin.getData(context).edit()
        appWidgetIds.forEach { widgetId ->
            editor.remove(HabitWidgetConfigureActivity.habitKeyForWidget(widgetId))
        }
        editor.apply()
    }

    private fun buildViews(
        context: Context,
        widgetId: Int,
        widgetData: SharedPreferences,
    ): RemoteViews {
        val habitId = habitIdFor(widgetId, widgetData)
        val accent = parseColorOr(
            widgetData.getString("habit_${habitId}_color", null),
            fallback = context.getColor(R.color.widget_primary),
        )
        val muted = context.getColor(R.color.widget_muted)

        return RemoteViews(context.packageName, R.layout.habit_widget).apply {
            if (habitId.isEmpty()) {
                // No habit to show: either none exist yet, or the app hasn't
                // run since this widget was placed.
                setTextViewText(R.id.habit_name, context.getString(R.string.habit_widget_empty_name))
                setTextViewText(
                    R.id.habit_status,
                    context.getString(R.string.habit_widget_empty_status),
                )
                setViewVisibility(R.id.habit_action, View.GONE)
                setViewVisibility(R.id.habit_week, View.GONE)
                setOnClickPendingIntent(
                    R.id.habit_widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("taskflow://habits"),
                    ),
                )
                return@apply
            }

            setTextViewText(
                R.id.habit_name,
                widgetData.getString("habit_${habitId}_name", null) ?: "Habit",
            )
            setTextViewText(
                R.id.habit_status,
                widgetData.getString("habit_${habitId}_status", null).orEmpty(),
            )
            // The habit's own colour is what makes one of these widgets tell
            // itself apart from another at a glance.
            setTextColor(R.id.habit_status, accent)

            // Blank means there's nothing sensible to log right now — today
            // isn't one of this habit's days.
            val action = widgetData.getString("habit_${habitId}_action", null).orEmpty()
            if (action.isBlank()) {
                setViewVisibility(R.id.habit_action, View.GONE)
            } else {
                setViewVisibility(R.id.habit_action, View.VISIBLE)
                setTextViewText(R.id.habit_action, action)
                setOnClickPendingIntent(
                    R.id.habit_action,
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("taskflow://habit?id=$habitId"),
                    ),
                )
            }

            setViewVisibility(R.id.habit_week, View.VISIBLE)
            renderWeek(
                this,
                widgetData.getString("habit_${habitId}_week", null).orEmpty(),
                accent,
                muted,
            )

            // Everything the button doesn't cover opens the habit's page.
            val open = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("taskflow://habitdetail?id=$habitId"),
            )
            setOnClickPendingIntent(R.id.habit_header, open)
            setOnClickPendingIntent(R.id.habit_week, open)
            setOnClickPendingIntent(R.id.habit_widget_root, open)
        }
    }

    /**
     * Which habit this widget tracks: its own choice, or the app's first
     * habit when it has none — a widget placed before per-widget choice
     * existed, or one whose habit has since been deleted, still shows
     * something real rather than going blank.
     */
    private fun habitIdFor(widgetId: Int, widgetData: SharedPreferences): String {
        val chosen = widgetData
            .getString(HabitWidgetConfigureActivity.habitKeyForWidget(widgetId), null)
            .orEmpty()
        // A name is written for every habit that exists, so its absence is
        // how a deleted habit is detected.
        if (chosen.isNotEmpty() &&
            widgetData.getString("habit_${chosen}_name", null) != null
        ) {
            return chosen
        }
        return widgetData.getString("habit_default_id", null).orEmpty()
    }

    /**
     * Draws the seven-day strip. Every dot gets both a drawable and a colour
     * filter on every update — RemoteViews replays whatever actions this
     * object carries, so a state that skipped one of them would inherit
     * whatever the previous render left there.
     */
    private fun renderWeek(
        views: RemoteViews,
        week: String,
        accent: Int,
        muted: Int,
    ) {
        for (i in 0 until WEEK_DAYS) {
            val viewId = DAY_VIEW_IDS[i]
            val day = week.getOrNull(i)
            val drawable = when (day) {
                DAY_DONE -> R.drawable.widget_dot_done
                DAY_OPEN, DAY_MISSED -> R.drawable.widget_dot_open
                // Rest days, and days before the habit existed.
                else -> R.drawable.widget_dot_skip
            }
            val tint = when (day) {
                DAY_DONE, DAY_OPEN -> accent
                else -> muted
            }
            views.setImageViewResource(viewId, drawable)
            // ImageView.setColorFilter(int) is @RemotableViewMethod, so it
            // can be driven by name from here.
            views.setInt(viewId, "setColorFilter", tint)
        }
    }

    /**
     * Parses the "#AARRGGBB" string Dart writes. Hand-rolled rather than
     * Color.parseColor so there's no deprecated API and no exception to
     * catch: anything malformed just falls back to the app's accent.
     */
    private fun parseColorOr(value: String?, fallback: Int): Int {
        val hex = value?.removePrefix("#") ?: return fallback
        if (hex.length != 8) return fallback
        return hex.toLongOrNull(16)?.toInt() ?: fallback
    }
}
