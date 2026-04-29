package com.vibesight.personal_finance

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget showing current month balance + a quick-add-expense
 * button. Data is written from the Flutter side via `home_widget` and read
 * here from SharedPreferences.
 */
class PFMHomeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.pfm_home_widget)

            val balance = widgetData.getString("balance", "—") ?: "—"
            val income = widgetData.getString("income", "—") ?: "—"
            val expense = widgetData.getString("expense", "—") ?: "—"

            views.setTextViewText(R.id.widget_balance, balance)
            views.setTextViewText(R.id.widget_income, income)
            views.setTextViewText(R.id.widget_expense, expense)

            // Tap on body opens the app.
            val openAppIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            views.setOnClickPendingIntent(R.id.widget_root, openAppIntent)

            // Quick "Add expense" — opens app with deep link `pfm://add_expense`.
            val addExpenseIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("pfm://add_expense")
            )
            views.setOnClickPendingIntent(R.id.widget_add_btn, addExpenseIntent)

            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
