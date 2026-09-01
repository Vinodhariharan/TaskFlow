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
 * Home screen widget for the one habit the app is set to track.
 *
 * Like the other two providers this is a dumb renderer: WidgetService in Dart
 * decides the name, the progress line, the streak text and even the seven-day
 * strip, which arrives as a seven-character string. Nothing here knows what a
 * streak is, so there's no second implementation of the rules to drift out of
 * sync with habit_stats.dart.
 *
 * Tapping the button logs the habit in the background; everything else opens
 * the habit's page in the app.
 */
class HabitWidgetProvider : HomeWidgetProvider() {

    /** Character codes shared with WidgetService._habitWeekStrip in Dart. */
    private companion object {
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
        val habitId = widgetData.getString("habit_id", null).orEmpty()
        val accent = parseColorOr(
            widgetData.getString("habit_color", null),
            fallback = context.getColor(R.color.widget_primary),
        )
        val muted = context.getColor(R.color.widget_muted)
        val week = widgetData.getString("habit_week", null).orEmpty()

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.habit_widget).apply {
                setTextViewText(
                    R.id.habit_name,
                    widgetData.getString("habit_name", null) ?: "Habit",
                )
                setTextViewText(
                    R.id.habit_progress,
                    widgetData.getString("habit_progress", null).orEmpty(),
                )
                setTextViewText(
                    R.id.habit_streak,
                    widgetData.getString("habit_streak", null).orEmpty(),
                )
                // The habit's own colour is what makes one of these widgets
                // tell itself apart from another at a glance.
                setTextColor(R.id.habit_streak, accent)

                // Blank means there's nothing sensible to log right now — no
                // habit chosen yet, or today isn't one of its days.
                val action = widgetData.getString("habit_action", null).orEmpty()
                if (action.isBlank() || habitId.isBlank()) {
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

                renderWeek(this, week, accent, muted)

                // Everything the button doesn't cover opens the app — the
                // habit's own page when there is one, the Habits tab
                // otherwise.
                val open = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse(
                        if (habitId.isBlank()) {
                            "taskflow://habits"
                        } else {
                            "taskflow://habitdetail?id=$habitId"
                        }
                    ),
                )
                setOnClickPendingIntent(R.id.habit_header, open)
                setOnClickPendingIntent(R.id.habit_week, open)
                setOnClickPendingIntent(R.id.habit_widget_root, open)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
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
