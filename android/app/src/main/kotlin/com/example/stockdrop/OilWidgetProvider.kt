package com.example.stockdrop

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.util.Log
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*
import kotlin.concurrent.thread

class OilWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateOilWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateOilWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.oil_widget)
        
        // Set refresh action
        val refreshIntent = Intent(context, OilWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
        }
        val refreshPendingIntent = PendingIntent.getBroadcast(
            context, appWidgetId, refreshIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.oil_refresh_button, refreshPendingIntent)

        // Get API key from SharedPreferences
        val prefs = context.getSharedPreferences("stockdrop_prefs", Context.MODE_PRIVATE)
        val apiKey = prefs.getString("fmp_api_key", null)
        
        if (apiKey.isNullOrEmpty()) {
            views.setTextViewText(R.id.oil_symbol, "OIL")
            views.setTextViewText(R.id.oil_price, "API Key Required")
            views.setTextViewText(R.id.oil_change, "")
            appWidgetManager.updateAppWidget(appWidgetId, views)
            return
        }

        // Fetch oil data in background thread
        thread {
            try {
                val oilQuote = fetchOilQuote(apiKey)
                val historicalData = fetchOilHistoricalData(apiKey)
                
                if (oilQuote != null) {
                    updateWidgetWithOilData(appWidgetManager, appWidgetId, views, oilQuote, historicalData)
                } else {
                    views.setTextViewText(R.id.oil_symbol, "OIL")
                    views.setTextViewText(R.id.oil_price, "Error loading data")
                    views.setTextViewText(R.id.oil_change, "")
                    appWidgetManager.updateAppWidget(appWidgetId, views)
                }
            } catch (e: Exception) {
                Log.e("OilWidget", "Error updating widget: ${e.message}")
                views.setTextViewText(R.id.oil_symbol, "OIL")
                views.setTextViewText(R.id.oil_price, "Network Error")
                views.setTextViewText(R.id.oil_change, "")
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }
    }
}

data class OilQuote(
    val price: Double,
    val changePercent: Double
)

data class OilHistoricalPoint(
    val date: String,
    val close: Double
)

private fun fetchOilQuote(apiKey: String): OilQuote? {
    return try {
        // Using Crude Oil (CL=F) or NYMEX Crude Oil
        val url = URL("https://financialmodelingprep.com/api/v3/quote/CLUSD?apikey=$apiKey")
        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.connectTimeout = 10000
        connection.readTimeout = 10000
        
        if (connection.responseCode == 200) {
            val response = connection.inputStream.bufferedReader().readText()
            val jsonArray = JSONArray(response)
            
            if (jsonArray.length() > 0) {
                val oilData = jsonArray.getJSONObject(0)
                OilQuote(
                    price = oilData.getDouble("price"),
                    changePercent = oilData.getDouble("changesPercentage")
                )
            } else null
        } else {
            Log.e("OilWidget", "HTTP error: ${connection.responseCode}")
            null
        }
    } catch (e: Exception) {
        Log.e("OilWidget", "Error parsing oil quote: ${e.message}")
        null
    }
}

private fun fetchOilHistoricalData(apiKey: String): List<OilHistoricalPoint> {
    return try {
        // Get last 90 days of data
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.DAY_OF_YEAR, -90)
        val fromDate = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(calendar.time)
        
        val toDate = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        
        val url = URL("https://financialmodelingprep.com/api/v3/historical-price-full/CLUSD?from=$fromDate&to=$toDate&apikey=$apiKey")
        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.connectTimeout = 15000
        connection.readTimeout = 15000
        
        if (connection.responseCode == 200) {
            val response = connection.inputStream.bufferedReader().readText()
            val jsonObject = JSONObject(response)
            val historicalArray = jsonObject.getJSONArray("historical")
            
            val dataPoints = mutableListOf<OilHistoricalPoint>()
            for (i in 0 until historicalArray.length()) {
                val dayData = historicalArray.getJSONObject(i)
                dataPoints.add(
                    OilHistoricalPoint(
                        date = dayData.getString("date"),
                        close = dayData.getDouble("close")
                    )
                )
            }
            
            // Reverse to get chronological order (oldest to newest)
            dataPoints.reversed()
        } else {
            emptyList()
        }
    } catch (e: Exception) {
        Log.e("OilWidget", "Error fetching historical data: ${e.message}")
        emptyList()
    }
}

private fun updateWidgetWithOilData(
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int,
    views: RemoteViews,
    quote: OilQuote,
    historicalData: List<OilHistoricalPoint>
) {
    // Update text fields
    views.setTextViewText(R.id.oil_symbol, "OIL")
    views.setTextViewText(R.id.oil_price, "$${String.format("%.2f", quote.price)}")
    
    val changeText = if (quote.changePercent >= 0) {
        "+${String.format("%.1f", quote.changePercent)}%"
    } else {
        "${String.format("%.1f", quote.changePercent)}%"
    }
    views.setTextViewText(R.id.oil_change, changeText)
    
    // Set change color - black for oil theme
    views.setTextColor(R.id.oil_change, Color.BLACK)
    
    // Chart removed - widget is now single height
    
    appWidgetManager.updateAppWidget(appWidgetId, views)
}