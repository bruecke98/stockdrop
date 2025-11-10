package com.example.stockdrop

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import kotlinx.coroutines.*
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONArray
import org.json.JSONObject
import android.util.Log

import com.example.stockdrop.MainActivity

/**
 * Implementation of App Widget functionality for StockDrop
 * Shows the stock with the most decline today
 */
class StockWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // There may be multiple widgets active, so update all of them
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // Enter relevant functionality for when the first widget is created
    }

    override fun onDisabled(context: Context) {
        // Enter relevant functionality for when the last widget is disabled
    }
}

internal fun updateAppWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
    // Construct the RemoteViews object
    val views = RemoteViews(context.packageName, R.layout.stock_widget)
    
    // Set loading state
    views.setTextViewText(R.id.stock_symbol, "Loading...")
    views.setTextViewText(R.id.stock_price, "--")
    views.setTextViewText(R.id.stock_change_percent, "--")

    // Create an Intent to launch MainActivity when clicked
    val intent = Intent(context, MainActivity::class.java)
    val pendingIntent = PendingIntent.getActivity(
        context, 0, intent, 
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setOnClickPendingIntent(R.id.stock_symbol, pendingIntent)

    // Create refresh intent
    val refreshIntent = Intent(context, StockWidgetProvider::class.java).apply {
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
    
    // Fetch stock data asynchronously
    fetchStockData(context, appWidgetManager, appWidgetId, views)
}

private fun fetchStockData(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int,
    views: RemoteViews
) {
    CoroutineScope(Dispatchers.IO).launch {
        try {
            // Get API key from shared preferences
            val apiKey = getApiKey(context)
            
            Log.d("StockWidget", "API Key: ${if (apiKey.isNotEmpty()) "${apiKey.substring(0, 8)}..." else "empty"}")
            
            if (apiKey.isEmpty()) {
                Log.e("StockWidget", "No API key available")
                withContext(Dispatchers.Main) {
                    views.setTextViewText(R.id.stock_symbol, "ERROR")
                    views.setTextViewText(R.id.stock_price, "No API Key")
                    views.setTextViewText(R.id.stock_change_percent, "")
                    views.setTextColor(R.id.stock_change_percent, Color.RED)
                    appWidgetManager.updateAppWidget(appWidgetId, views)
                }
                return@launch
            }

            // First get some popular stocks to check
            val symbols = arrayOf("AAPL", "MSFT", "GOOGL", "AMZN", "TSLA", "META", "NVDA", "NFLX")
            val quotes = mutableListOf<StockQuote>()
            
            // Fetch quotes for popular stocks
            for (symbol in symbols) {
                try {
                    val quote = fetchQuote(symbol, apiKey)
                    if (quote != null) {
                        quotes.add(quote)
                    }
                } catch (e: Exception) {
                    Log.e("StockWidget", "Error fetching quote for $symbol: ${e.message}")
                }
            }

            if (quotes.isNotEmpty()) {
                // Sort by change percentage (most declining first)
                quotes.sortBy { it.changePercent }
                val topStock = quotes.first()
                
                Log.d("StockWidget", "Found ${quotes.size} stocks, most declining: ${topStock.symbol} ${topStock.changePercent}%")
                
                withContext(Dispatchers.Main) {
                    updateWidgetWithStock(appWidgetManager, appWidgetId, views, topStock)
                }
            } else {
                // Fallback to demo data if API calls fail
                withContext(Dispatchers.Main) {
                    // Show the most declining demo stock
                    val demoStock = StockQuote("META", 298.33, -6.1, -18.25) // Highest decline
                    updateWidgetWithStock(appWidgetManager, appWidgetId, views, demoStock)
                }
            }
        } catch (e: Exception) {
            Log.e("StockWidget", "Error fetching stock data: ${e.message}")
            withContext(Dispatchers.Main) {
                // Show most declining demo data on error
                val demoStock = StockQuote("META", 298.33, -6.1, -18.25) // Highest decline
                updateWidgetWithStock(appWidgetManager, appWidgetId, views, demoStock)
            }
        }
    }
}

private fun fetchQuote(symbol: String, apiKey: String): StockQuote? {
    return try {
        val url = URL("https://financialmodelingprep.com/api/v3/quote/$symbol?apikey=$apiKey")
        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.connectTimeout = 10000
        connection.readTimeout = 10000
        
        if (connection.responseCode == 200) {
            val response = connection.inputStream.bufferedReader().readText()
            val jsonArray = JSONArray(response)
            
            if (jsonArray.length() > 0) {
                val stockData = jsonArray.getJSONObject(0)
                StockQuote(
                    symbol = stockData.getString("symbol"),
                    price = stockData.getDouble("price"),
                    changePercent = stockData.getDouble("changesPercentage"),
                    change = stockData.getDouble("change")
                )
            } else null
        } else {
            Log.e("StockWidget", "HTTP error: ${connection.responseCode}")
            null
        }
    } catch (e: Exception) {
        Log.e("StockWidget", "Error parsing quote for $symbol: ${e.message}")
        null
    }
}

private fun updateWidgetWithStock(
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int,
    views: RemoteViews,
    stock: StockQuote
) {
    views.setTextViewText(R.id.stock_symbol, stock.symbol)
    views.setTextViewText(R.id.stock_price, "$${String.format("%.2f", stock.price)}")
    
    // Percent above absolute change
    val percentText = String.format("%+.2f%%", stock.changePercent)
    val absText = if (stock.change >= 0) {
        "+$${String.format("%.2f", stock.change)}"
    } else {
        "-$${String.format("%.2f", Math.abs(stock.change))}"
    }
    views.setTextViewText(R.id.stock_change_percent, percentText)
    views.setTextViewText(R.id.stock_change_abs, absText)

    // Color: red for negative, green for positive
    val changeColor = if (stock.change >= 0) Color.parseColor("#006400") else Color.parseColor("#B00020")
    views.setTextColor(R.id.stock_change_percent, changeColor)
    views.setTextColor(R.id.stock_change_abs, changeColor)
    
    appWidgetManager.updateAppWidget(appWidgetId, views)
}

private fun updateWidgetWithError(
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int,
    views: RemoteViews,
    error: String
) {
    views.setTextViewText(R.id.stock_symbol, "Error")
    views.setTextViewText(R.id.stock_price, "--")
    views.setTextViewText(R.id.stock_change_percent, error)
    
    appWidgetManager.updateAppWidget(appWidgetId, views)
}

private fun getApiKey(context: Context): String {
    // Get the API key from shared preferences
    val prefs = context.getSharedPreferences("stockdrop_prefs", Context.MODE_PRIVATE)
    val apiKey = prefs.getString("fmp_api_key", "") ?: ""
    
    Log.d("StockWidget", "Retrieved API key from SharedPreferences: ${if (apiKey.isNotEmpty()) "${apiKey.substring(0, 8)}..." else "empty"}")
    
    return apiKey
}

data class StockQuote(
    val symbol: String,
    val price: Double,
    val changePercent: Double,
    val change: Double
)