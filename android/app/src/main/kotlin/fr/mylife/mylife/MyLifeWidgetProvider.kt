package fr.mylife.mylife

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class MyLifeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.mylife_widget).apply {
                setTextViewText(R.id.w_calories, widgetData.getString("calories", "—"))
                setTextViewText(R.id.w_water, widgetData.getString("water", "—"))
                setTextViewText(R.id.w_balance, widgetData.getString("balance", "—"))

                val launchIntent = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                val pending = PendingIntent.getActivity(
                    context, 0, launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.w_root, pending)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
