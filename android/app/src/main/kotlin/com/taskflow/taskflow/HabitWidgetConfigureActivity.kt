package com.taskflow.taskflow

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.ListView
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONException

/**
 * Asks which habit a newly placed habit widget should track, and runs again
 * when the widget is reconfigured from the launcher.
 *
 * The list it offers is written by Dart (WidgetService, key "habit_options")
 * rather than read out of the app's own storage: habits live in Flutter's
 * SharedPreferences in a plugin-specific encoding, and decoding that here
 * would put a second, drifting copy of the habit model on the native side.
 * This way the only thing Kotlin knows about a habit is its id and its name.
 *
 * The choice is stored per widget id, so several of these can sit on the home
 * screen tracking different habits.
 */
class HabitWidgetConfigureActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Backing out without choosing must leave no widget behind, so the
        // cancelled result is set up front and only replaced on a pick.
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.habit_widget_configure)

        val widgetData = HomeWidgetPlugin.getData(this)
        val choices = parseChoices(widgetData.getString(HABIT_OPTIONS_KEY, null))
        val list = findViewById<ListView>(R.id.habit_choice_list)

        if (choices.isEmpty()) {
            // Nothing to choose from — either the app has never run, or there
            // genuinely are no habits yet.
            list.visibility = View.GONE
            findViewById<TextView>(R.id.habit_choice_empty).visibility = View.VISIBLE
            return
        }

        list.adapter = ArrayAdapter(
            this,
            R.layout.habit_choice_row,
            R.id.habit_choice_name,
            choices.map { it.name },
        )
        list.onItemClickListener =
            AdapterView.OnItemClickListener { _, _, position, _ ->
                widgetData.edit()
                    .putString(habitKeyForWidget(appWidgetId), choices[position].id)
                    .apply()

                // Draw it straight away. Nothing else would until the next
                // scheduled update or the next time the app runs, which would
                // leave a blank widget sitting there in the meantime.
                HabitWidgetProvider().onUpdate(
                    this,
                    AppWidgetManager.getInstance(this),
                    intArrayOf(appWidgetId),
                    widgetData,
                )

                setResult(
                    RESULT_OK,
                    Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
                )
                finish()
            }
    }

    private data class HabitChoice(val id: String, val name: String)

    /** Parses `[{"id":…,"name":…}]`; anything malformed offers nothing. */
    private fun parseChoices(raw: String?): List<HabitChoice> {
        if (raw.isNullOrBlank()) return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).mapNotNull { index ->
                val item = array.optJSONObject(index) ?: return@mapNotNull null
                val id = item.optString("id")
                if (id.isEmpty()) return@mapNotNull null
                HabitChoice(id, item.optString("name").ifEmpty { "Habit" })
            }
        } catch (_: JSONException) {
            emptyList()
        }
    }

    companion object {
        const val HABIT_OPTIONS_KEY = "habit_options"

        /** Which habit one placed widget tracks. */
        fun habitKeyForWidget(appWidgetId: Int) = "habit_id_$appWidgetId"
    }
}
