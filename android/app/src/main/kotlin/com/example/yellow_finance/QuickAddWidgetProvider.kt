package com.example.yellow_finance

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * Static "Quick Add" home-screen widget: five buttons that deep-link into the
 * app's add flows. It shows no user data, so there is nothing to refresh — the
 * views are only (re)built when the launcher asks.
 *
 * The URLs are resolved by `HomeWidgetService` in Dart; keep them in sync with
 * it and with the iOS widget.
 */
class QuickAddWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_quick_add)
        for ((viewId, action) in ACTIONS) {
            // Each intent differs by its data URI, so the PendingIntents stay
            // distinct even though the plugin gives them all request code 0.
            val intent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("yellowfinance://add/$action?homeWidget"),
            )
            views.setOnClickPendingIntent(viewId, intent)
        }
        appWidgetManager.updateAppWidget(appWidgetIds, views)
    }

    private companion object {
        val ACTIONS = listOf(
            R.id.tile_expense to "expense",
            R.id.tile_income to "income",
            R.id.tile_task to "task",
            R.id.tile_sport to "sport",
            R.id.tile_diary to "diary",
        )
    }
}
