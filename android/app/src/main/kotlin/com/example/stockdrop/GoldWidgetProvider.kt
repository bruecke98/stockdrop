package com.example.stockdrop

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.util.Log
import android.widget.RemoteViews
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.max
import kotlin.math.min

import com.example.stockdrop.MainActivity

class GoldWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateGoldWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // Called when the first widget is created
    }

    override fun onDisabled(context: Context) {
        // Called when the last widget is removed
    }
}

private fun updateGoldWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
    val views = RemoteViews(context.packageName, R.layout.gold_widget)
    
    // Set loading state
    views.setTextViewText(R.id.gold_symbol, "GOLD")
    views.setTextViewText(R.id.gold_price, "Loading...")
    views.setTextViewText(R.id.gold_change_percent, "--")
    views.setTextViewText(R.id.gold_change_abs, "")

    // Create an Intent to launch MainActivity when clicked
    val intent = Intent(context, MainActivity::class.java)
    val pendingIntent = PendingIntent.getActivity(
        context, 0, intent, 
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setOnClickPendingIntent(R.id.gold_widget_container, pendingIntent)

    // Create refresh intent
    val refreshIntent = Intent(context, GoldWidgetProvider::class.java).apply {
        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
    }
    val refreshPendingIntent = PendingIntent.getBroadcast(
        context, appWidgetId, refreshIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setOnClickPendingIntent(R.id.refresh_button, refreshPendingIntent)

    // Update widget with loading state first
    appWidgetManager.updateAppWidget(appWidgetId, views)
    
    // Fetch gold data asynchronously
    fetchGoldData(context, appWidgetManager, appWidgetId, views)
}

private fun fetchGoldData(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int,
    views: RemoteViews
) {
    CoroutineScope(Dispatchers.IO).launch {
        try {
            // Get API key from shared preferences
            val apiKey = getApiKey(context)
            
            Log.d("GoldWidget", "API Key: ${if (apiKey.isNotEmpty()) "${apiKey.substring(0, 8)}..." else "empty"}")
            
            if (apiKey.isEmpty()) {
                Log.e("GoldWidget", "No API key available")
                withContext(Dispatchers.Main) {
                    views.setTextViewText(R.id.gold_symbol, "GOLD")
                    views.setTextViewText(R.id.gold_price, "No API Key")
                    views.setTextViewText(R.id.gold_change_percent, "")
                    views.setTextViewText(R.id.gold_change_abs, "")
                    appWidgetManager.updateAppWidget(appWidgetId, views)
                }
                return@launch
            }

            // Fetch current gold price
            val currentQuote = fetchGoldQuote(apiKey)
            // Fetch historical data for chart
            val historicalData = fetchGoldHistoricalData(apiKey)
            
            if (currentQuote != null) {
                Log.d("GoldWidget", "Gold price: $${currentQuote.price}, Change: ${currentQuote.changePercent}%")
                
                withContext(Dispatchers.Main) {
                    updateWidgetWithGoldData(appWidgetManager, appWidgetId, views, currentQuote, historicalData)
                }
            } else {
                // Fallback to demo data if API calls fail
                withContext(Dispatchers.Main) {
                    val demoQuote = GoldQuote(2025.50, 1.2, 24.30)
                    updateWidgetWithGoldData(appWidgetManager, appWidgetId, views, demoQuote, emptyList())
                }
            }
        } catch (e: Exception) {
            Log.e("GoldWidget", "Error fetching gold data: ${e.message}")
            withContext(Dispatchers.Main) {
                // Show demo data on error
                val demoQuote = GoldQuote(2025.50, 1.2, 24.30)
                updateWidgetWithGoldData(appWidgetManager, appWidgetId, views, demoQuote, emptyList())
            }
        }
    }
}

private fun fetchGoldQuote(apiKey: String): GoldQuote? {
    return try {
        val url = URL("https://financialmodelingprep.com/api/v3/quote/GCUSD?apikey=$apiKey")
        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.connectTimeout = 10000
        connection.readTimeout = 10000
        
        if (connection.responseCode == 200) {
            val response = connection.inputStream.bufferedReader().readText()
            val jsonArray = JSONArray(response)
            
            if (jsonArray.length() > 0) {
                val goldData = jsonArray.getJSONObject(0)
                GoldQuote(
                    price = goldData.getDouble("price"),
                    changePercent = goldData.getDouble("changesPercentage"),
                    change = goldData.getDouble("change")
                )
            } else null
        } else {
            Log.e("GoldWidget", "HTTP error: ${connection.responseCode}")
            null
        }
    } catch (e: Exception) {
        Log.e("GoldWidget", "Error parsing gold quote: ${e.message}")
        null
    }
}

private fun fetchGoldHistoricalData(apiKey: String): List<GoldHistoricalPoint> {
    return try {
        // Get last 90 days of data
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.DAY_OF_YEAR, -90)
        val fromDate = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(calendar.time)
        
        val toDate = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        
        val url = URL("https://financialmodelingprep.com/api/v3/historical-price-full/GCUSD?from=$fromDate&to=$toDate&apikey=$apiKey")
        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.connectTimeout = 15000
        connection.readTimeout = 15000
        
        if (connection.responseCode == 200) {
            val response = connection.inputStream.bufferedReader().readText()
            val jsonObject = JSONObject(response)
            val historical = jsonObject.getJSONArray("historical")
            
            val points = mutableListOf<GoldHistoricalPoint>()
            for (i in 0 until historical.length()) {
                val point = historical.getJSONObject(i)
                points.add(
                    GoldHistoricalPoint(
                        date = point.getString("date"),
                        close = point.getDouble("close")
                    )
                )
            }
            points.reversed() // Most recent first
        } else {
            Log.e("GoldWidget", "Historical data HTTP error: ${connection.responseCode}")
            emptyList()
        }
    } catch (e: Exception) {
        Log.e("GoldWidget", "Error fetching historical data: ${e.message}")
        emptyList()
    }
}

private fun updateWidgetWithGoldData(
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int,
    views: RemoteViews,
    quote: GoldQuote,
    historicalData: List<GoldHistoricalPoint>
) {
    // Update text fields
    views.setTextViewText(R.id.gold_symbol, "GOLD")
    views.setTextViewText(R.id.gold_price, "$${String.format("%.2f", quote.price)}")
    
    // Split percent and absolute change into separate views
    val percentText = String.format("%+.2f%%", quote.changePercent)
    val absText = if (quote.change >= 0) {
        "+$${String.format("%.2f", quote.change)}"
    } else {
        "-$${String.format("%.2f", Math.abs(quote.change))}"
    }

    views.setTextViewText(R.id.gold_change_percent, percentText)
    views.setTextViewText(R.id.gold_change_abs, absText)

    // Color: keep black for gold widget values but adjust tint if negative/positive
    val changeColor = if (quote.change >= 0) Color.parseColor("#006400") else Color.parseColor("#8B0000")
    views.setTextColor(R.id.gold_change_percent, changeColor)
    views.setTextColor(R.id.gold_change_abs, changeColor)
    
    // Chart removed - widget is now single height
    
    appWidgetManager.updateAppWidget(appWidgetId, views)
}

private fun getApiKey(context: Context): String {
    // Get the API key from shared preferences
    val prefs = context.getSharedPreferences("stockdrop_prefs", Context.MODE_PRIVATE)
    val apiKey = prefs.getString("fmp_api_key", "") ?: ""
    
    Log.d("GoldWidget", "Retrieved API key from SharedPreferences: ${if (apiKey.isNotEmpty()) "${apiKey.substring(0, 8)}..." else "empty"}")
    
    return apiKey
}

data class GoldQuote(
    val price: Double,
    val changePercent: Double,
    val change: Double
)

data class GoldHistoricalPoint(
    val date: String,
    val close: Double
)