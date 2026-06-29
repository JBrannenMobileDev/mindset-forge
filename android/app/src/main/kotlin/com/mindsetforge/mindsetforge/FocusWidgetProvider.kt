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
                views.setTextViewText(R.id.focus_text, "Set your #1 focus for today")
                stylePrimaryButton(context, views, "Set focus")
                views.setOnClickPendingIntent(R.id.focus_button, openPendingIntent)
            }
            "focus_open" -> {
                views.setTextViewText(R.id.focus_text, payload.focusText)
                stylePrimaryButton(context, views, "Mark done")
                val completePendingIntent = HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse(COMPLETE_URI),
                )
                views.setOnClickPendingIntent(R.id.focus_button, completePendingIntent)
            }
            else -> {
                // focus_done / on_track — focus complete for today.
                views.setTextViewText(R.id.focus_text, payload.focusText)
                styleDoneButton(context, views)
                views.setOnClickPendingIntent(R.id.focus_button, openPendingIntent)
            }
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
                streak = json.optInt("streak", 0),
            )
        } catch (e: Exception) {
            Payload()
        }
    }

    private data class Payload(
        val state: String = "set_focus",
        val focusText: String = "",
        val streak: Int = 0,
    )
}
