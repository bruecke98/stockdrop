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

import com.example.stockdrop.MainActivity
import kotlin.math.max
import kotlin.math.min

class SilverWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateSilverWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // Called when the first widget is created
    }

    override fun onDisabled(context: Context) {
        // Called when the last widget is removed
    }
}

private fun updateSilverWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
    val views = RemoteViews(context.packageName, R.layout.silver_widget)
    
    // Set loading state
    views.setTextViewText(R.id.silver_symbol, "SILVER")
    views.setTextViewText(R.id.silver_price, "Loading...")
    views.setTextViewText(R.id.silver_change_percent, "--")

    // Create an Intent to launch MainActivity when clicked
    val intent = Intent(context, MainActivity::class.java)
    val pendingIntent = PendingIntent.getActivity(
        context, 0, intent, 
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setOnClickPendingIntent(R.id.silver_widget_container, pendingIntent)

    // Create refresh intent
    val refreshIntent = Intent(context, SilverWidgetProvider::class.java).apply {
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
    
    // Fetch silver data asynchronously
    fetchSilverData(context, appWidgetManager, appWidgetId, views)
}

private fun fetchSilverData(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int,
    views: RemoteViews
) {
    CoroutineScope(Dispatchers.IO).launch {
        try {
            // Get API key from shared preferences
            val apiKey = getApiKey(context)
            
            Log.d("SilverWidget", "API Key: ${if (apiKey.isNotEmpty()) "${apiKey.substring(0, 8)}..." else "empty"}")
            
            if (apiKey.isEmpty()) {
                Log.e("SilverWidget", "No API key available")
                withContext(Dispatchers.Main) {
                    views.setTextViewText(R.id.silver_symbol, "SILVER")
                    views.setTextViewText(R.id.silver_price, "No API Key")
                    views.setTextViewText(R.id.silver_change_percent, "")
                    appWidgetManager.updateAppWidget(appWidgetId, views)
                }
                return@launch
            }

            // Fetch current silver price
            val currentQuote = fetchSilverQuote(apiKey)
            // Fetch historical data for chart
            val historicalData = fetchSilverHistoricalData(apiKey)
            
            if (currentQuote != null) {
                Log.d("SilverWidget", "Silver price: $${currentQuote.price}, Change: ${currentQuote.changePercent}%")
                
                withContext(Dispatchers.Main) {
                    updateWidgetWithSilverData(appWidgetManager, appWidgetId, views, currentQuote, historicalData)
                }
            } else {
                // Fallback to demo data if API calls fail
                withContext(Dispatchers.Main) {
                    val demoQuote = SilverQuote(24.75, -0.8, -0.20)
                    updateWidgetWithSilverData(appWidgetManager, appWidgetId, views, demoQuote, emptyList())
                }
            }
        } catch (e: Exception) {
            Log.e("SilverWidget", "Error fetching silver data: ${e.message}")
            withContext(Dispatchers.Main) {
                // Show demo data on error
                val demoQuote = SilverQuote(24.75, -0.8, -0.20)
                updateWidgetWithSilverData(appWidgetManager, appWidgetId, views, demoQuote, emptyList())
            }
        }
    }
}

private fun fetchSilverQuote(apiKey: String): SilverQuote? {
    return try {
        val url = URL("https://financialmodelingprep.com/api/v3/quote/SIUSD?apikey=$apiKey")
        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.connectTimeout = 10000
        connection.readTimeout = 10000
        
        if (connection.responseCode == 200) {
            val response = connection.inputStream.bufferedReader().readText()
            val jsonArray = JSONArray(response)
            
            if (jsonArray.length() > 0) {
                val silverData = jsonArray.getJSONObject(0)
                SilverQuote(
                    price = silverData.getDouble("price"),
                    changePercent = silverData.getDouble("changesPercentage"),
                    change = silverData.getDouble("change")
                )
            } else null
        } else {
            Log.e("SilverWidget", "HTTP error: ${connection.responseCode}")
            null
        }
    } catch (e: Exception) {
        Log.e("SilverWidget", "Error parsing silver quote: ${e.message}")
        null
    }
}

private fun fetchSilverHistoricalData(apiKey: String): List<SilverHistoricalPoint> {
    return try {
        // Get last 90 days of data
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.DAY_OF_YEAR, -90)
        val fromDate = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(calendar.time)
        
        val toDate = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        
        val url = URL("https://financialmodelingprep.com/api/v3/historical-price-full/SIUSD?from=$fromDate&to=$toDate&apikey=$apiKey")
        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.connectTimeout = 15000
        connection.readTimeout = 15000
        
        if (connection.responseCode == 200) {
            val response = connection.inputStream.bufferedReader().readText()
            val jsonObject = JSONObject(response)
            val historical = jsonObject.getJSONArray("historical")
            
            val points = mutableListOf<SilverHistoricalPoint>()
            for (i in 0 until historical.length()) {
                val point = historical.getJSONObject(i)
                points.add(
                    SilverHistoricalPoint(
                        date = point.getString("date"),
                        close = point.getDouble("close")
                    )
                )
            }
            points.reversed() // Most recent first
        } else {
            Log.e("SilverWidget", "Historical data HTTP error: ${connection.responseCode}")
            emptyList()
        }
    } catch (e: Exception) {
        Log.e("SilverWidget", "Error fetching historical data: ${e.message}")
        emptyList()
    }
}

private fun updateWidgetWithSilverData(
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int,
    views: RemoteViews,
    quote: SilverQuote,
    historicalData: List<SilverHistoricalPoint>
) {
    // Update text fields
    views.setTextViewText(R.id.silver_symbol, "SILVER")
    views.setTextViewText(R.id.silver_price, "$${String.format("%.2f", quote.price)}")
    
    // Percent above absolute change
    val percentText = String.format("%+.2f%%", quote.changePercent)
    val absText = if (quote.change >= 0) {
        "+$${String.format("%.2f", quote.change)}"
    } else {
        "-$${String.format("%.2f", Math.abs(quote.change))}"
    }
    views.setTextViewText(R.id.silver_change_percent, percentText)
    views.setTextViewText(R.id.silver_change_abs, absText)

    // Color: green for up, red for down
    val changeColor = if (quote.change >= 0) Color.parseColor("#006400") else Color.parseColor("#B00020")
    views.setTextColor(R.id.silver_change_percent, changeColor)
    views.setTextColor(R.id.silver_change_abs, changeColor)
    
    // Chart removed - widget is now single height
    
    appWidgetManager.updateAppWidget(appWidgetId, views)
}

private fun getApiKey(context: Context): String {
    // Get the API key from shared preferences
    val prefs = context.getSharedPreferences("stockdrop_prefs", Context.MODE_PRIVATE)
    val apiKey = prefs.getString("fmp_api_key", "") ?: ""
    
    Log.d("SilverWidget", "Retrieved API key from SharedPreferences: ${if (apiKey.isNotEmpty()) "${apiKey.substring(0, 8)}..." else "empty"}")
    
    return apiKey
}

data class SilverQuote(
    val price: Double,
    val changePercent: Double,
    val change: Double
)

data class SilverHistoricalPoint(
    val date: String,
    val close: Double
)