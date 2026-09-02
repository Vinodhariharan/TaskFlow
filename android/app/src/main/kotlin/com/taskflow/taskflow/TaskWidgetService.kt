package com.taskflow.taskflow

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONException

/**
 * Feeds the Tasks widget's scrolling list.
 *
 * A widget can only scroll through a collection view, and a collection view
 * needs one of these behind it — three fixed rows in the layout, which is what
 * this replaces, could never scroll however tall the widget got.
 *
 * The rows come from a JSON array Dart writes (WidgetService, key
 * "task_list"), so which tasks count as today's and what order they're in
 * stays in TaskService rather than being decided again here.
 */
class TaskWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        TaskRemoteViewsFactory(applicationContext)
}

private class TaskRemoteViewsFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {

    private var tasks: List<WidgetTask> = emptyList()

    private data class WidgetTask(val id: String, val title: String)

    override fun onCreate() = Unit

    /**
     * Called on create and on every notifyAppWidgetViewDataChanged. Reading
     * the whole list here rather than per row keeps getViewAt cheap, which
     * matters because it runs for every row the user scrolls past.
     */
    override fun onDataSetChanged() {
        tasks = parseTasks(
            HomeWidgetPlugin.getData(context).getString(TASK_LIST_KEY, null),
        )
    }

    override fun onDestroy() {
        tasks = emptyList()
    }

    override fun getCount() = tasks.size

    override fun getViewAt(position: Int): RemoteViews {
        val task = tasks.getOrNull(position) ?: return loadingView()
        return RemoteViews(context.packageName, R.layout.task_widget_row).apply {
            setTextViewText(R.id.task_row_title, task.title)
            // Rows in a collection can't carry a PendingIntent of their own —
            // they fill in the one template the provider set on the list. See
            // TaskWidgetProvider for what that template does.
            setOnClickFillInIntent(
                R.id.task_widget_row,
                Intent().setData(Uri.parse("taskflow://toggle?id=${task.id}")),
            )
        }
    }

    private fun loadingView() = RemoteViews(context.packageName, R.layout.task_widget_row)

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount() = 1

    /** Stable enough for the list to animate rather than flash on update. */
    override fun getItemId(position: Int) =
        tasks.getOrNull(position)?.id?.hashCode()?.toLong() ?: position.toLong()

    override fun hasStableIds() = true

    /** Parses `[{"id":…,"title":…}]`; anything malformed lists nothing. */
    private fun parseTasks(raw: String?): List<WidgetTask> {
        if (raw.isNullOrBlank()) return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).mapNotNull { index ->
                val item = array.optJSONObject(index) ?: return@mapNotNull null
                val id = item.optString("id")
                if (id.isEmpty()) return@mapNotNull null
                WidgetTask(id, item.optString("title").ifEmpty { "Untitled" })
            }
        } catch (_: JSONException) {
            emptyList()
        }
    }

    companion object {
        const val TASK_LIST_KEY = "task_list"
    }
}
