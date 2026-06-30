package com.mindsetforge.mindsetforge

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject

/**
 * Home-screen widget that mirrors the in-app "Today's Focus" hero. Reads the
 * single JSON payload written by [WidgetSyncService] through `home_widget` and
 * renders focus text, streak, and a contextual action button.
 *
 * Tapping the card opens the app on the dashboard; the action button either
 * opens the app (to set a focus) or fires a background "Mark done" broadcast
 * that flows into the same Dart `widgetInteractiveCallback` as iOS.
 */
class FocusWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val PAYLOAD_KEY = "widget_payload"
        private const val OPEN_URI = "mindsetforge://focus"
        private const val COMPLETE_URI = "mindsetforge://completeFocus"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val payload = parsePayload(widgetData.getString(PAYLOAD_KEY, null))

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.focus_widget)
            bind(context, views, payload)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun bind(context: Context, views: RemoteViews, payload: Payload) {
        // Whole card opens the app on the dashboard.
        val openPendingIntent: PendingIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse(OPEN_URI),
        )
        views.setOnClickPendingIntent(R.id.focus_widget_root, openPendingIntent)

        // Streak chip — hidden when there is no active streak.
        if (payload.streak > 0) {
            views.setViewVisibility(R.id.focus_streak, android.view.View.VISIBLE)
            views.setTextViewText(R.id.focus_streak, "\uD83D\uDD25 ${payload.streak}")
        } else {
            views.setViewVisibility(R.id.focus_streak, android.view.View.GONE)
        }

        when (payload.state) {
            "set_focus" -> {
                hideWeekRow(views)
                views.setTextViewText(R.id.focus_text, "Set your #1 focus for today")
                stylePrimaryButton(context, views, "Set focus")
                views.setOnClickPendingIntent(R.id.focus_button, openPendingIntent)
            }
            "focus_open" -> {
                hideWeekRow(views)
                views.setTextViewText(R.id.focus_text, payload.focusText)
                stylePrimaryButton(context, views, "Mark done")
                val completePendingIntent = HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse(COMPLETE_URI),
                )
                views.setOnClickPendingIntent(R.id.focus_button, completePendingIntent)
            }
            else -> {
                // focus_done / on_track — focus complete for today. Lead with the
                // resolver headline ("You're On Track") and show the 7-day chain.
                val headline = payload.headline.ifEmpty { payload.focusText }
                views.setTextViewText(R.id.focus_text, headline)
                bindWeekRow(context, views, payload)
                styleDoneButton(context, views)
                views.setOnClickPendingIntent(R.id.focus_button, openPendingIntent)
            }
        }
    }

    /** Day-cell view ids in order (oldest → newest, index 6 = today). */
    private val dayIds = intArrayOf(
        R.id.focus_day_0, R.id.focus_day_1, R.id.focus_day_2, R.id.focus_day_3,
        R.id.focus_day_4, R.id.focus_day_5, R.id.focus_day_6,
    )
    private val dayLabelIds = intArrayOf(
        R.id.focus_day_label_0, R.id.focus_day_label_1, R.id.focus_day_label_2,
        R.id.focus_day_label_3, R.id.focus_day_label_4, R.id.focus_day_label_5,
        R.id.focus_day_label_6,
    )

    private fun hideWeekRow(views: RemoteViews) {
        views.setViewVisibility(R.id.focus_week_row, android.view.View.GONE)
        views.setViewVisibility(R.id.focus_week_caption, android.view.View.GONE)
    }

    /** Renders the 7-day streak chain. Today (index 6) reads as in-progress when
     *  it has not yet qualified, since completing the focus alone doesn't earn
     *  the streak day (needs 5+/9 wins). */
    private fun bindWeekRow(context: Context, views: RemoteViews, payload: Payload) {
        if (payload.weekStreak.size != 7) {
            hideWeekRow(views)
            return
        }
        views.setViewVisibility(R.id.focus_week_row, android.view.View.VISIBLE)

        val flame = "\uD83D\uDD25"
        val white = ContextCompat.getColor(context, R.color.widgetOnPrimary)
        val success = ContextCompat.getColor(context, R.color.widgetSuccess)
        val muted = ContextCompat.getColor(context, R.color.widgetTextMuted)

        for (i in 0 until 7) {
            val isToday = i == 6
            val qualifying = payload.weekStreak[i]

            // Weekday letter.
            val label = payload.weekLabels.getOrElse(i) { "" }
            views.setTextViewText(dayLabelIds[i], label)
            views.setTextColor(dayLabelIds[i], if (isToday) success else muted)

            // Status dot.
            when {
                qualifying -> {
                    views.setInt(dayIds[i], "setBackgroundResource", R.drawable.focus_widget_day_filled)
                    views.setTextViewText(dayIds[i], flame)
                    views.setTextColor(dayIds[i], white)
                }
                isToday -> {
                    views.setInt(dayIds[i], "setBackgroundResource", R.drawable.focus_widget_day_today)
                    views.setTextViewText(dayIds[i], flame)
                    views.setTextColor(dayIds[i], success)
                }
                else -> {
                    views.setInt(dayIds[i], "setBackgroundResource", R.drawable.focus_widget_day_empty)
                    views.setTextViewText(dayIds[i], "")
                }
            }
        }

        if (payload.weekCaption.isNotEmpty()) {
            views.setViewVisibility(R.id.focus_week_caption, android.view.View.VISIBLE)
            views.setTextViewText(R.id.focus_week_caption, payload.weekCaption)
        } else {
            views.setViewVisibility(R.id.focus_week_caption, android.view.View.GONE)
        }
    }

    private fun stylePrimaryButton(context: Context, views: RemoteViews, label: String) {
        views.setTextViewText(R.id.focus_button, label)
        views.setInt(R.id.focus_button, "setBackgroundResource", R.drawable.focus_widget_button)
        views.setTextColor(
            R.id.focus_button,
            ContextCompat.getColor(context, R.color.widgetOnPrimary),
        )
    }

    private fun styleDoneButton(context: Context, views: RemoteViews) {
        views.setTextViewText(R.id.focus_button, "Done \u2713")
        views.setInt(
            R.id.focus_button,
            "setBackgroundResource",
            R.drawable.focus_widget_button_done,
        )
        views.setTextColor(
            R.id.focus_button,
            ContextCompat.getColor(context, R.color.widgetSuccess),
        )
    }

    private fun parsePayload(raw: String?): Payload {
        if (raw.isNullOrEmpty()) return Payload()
        return try {
            val json = JSONObject(raw)
            Payload(
                state = json.optString("state", "set_focus"),
                focusText = json.optString("focusText", ""),
                headline = json.optString("headline", ""),
                streak = json.optInt("streak", 0),
                completedCount = json.optInt("completedCount", 0),
                totalCount = json.optInt("totalCount", 9),
                weekStreak = json.optJSONArray("weekStreak").toBoolList(),
                weekLabels = json.optJSONArray("weekLabels").toStringList(),
                weekCaption = json.optString("weekCaption", ""),
            )
        } catch (e: Exception) {
            Payload()
        }
    }

    private fun org.json.JSONArray?.toBoolList(): List<Boolean> {
        if (this == null) return emptyList()
        return (0 until length()).map { optBoolean(it, false) }
    }

    private fun org.json.JSONArray?.toStringList(): List<String> {
        if (this == null) return emptyList()
        return (0 until length()).map { optString(it, "") }
    }

    private data class Payload(
        val state: String = "set_focus",
        val focusText: String = "",
        val headline: String = "",
        val streak: Int = 0,
        val completedCount: Int = 0,
        val totalCount: Int = 9,
        val weekStreak: List<Boolean> = emptyList(),
        val weekLabels: List<String> = emptyList(),
        val weekCaption: String = "",
    )
}
