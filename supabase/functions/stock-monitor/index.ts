import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface Favorite {
  symbol: string;
  user_id: string;
  created_at: string;
}

interface UserSetting {
  user_id: string;
  notification_threshold: number;
}

interface StockPrice {
  symbol: string;
  price: number;
  change: number;
  changesPercentage: number;
  volume: number;
  timestamp: string;
}

interface Notification {
  user_id: string;
  symbol: string;
  price: number;
  change_percent: number;
  threshold: number;
  message: string;
}

interface NotificationRecord {
  user_id: string;
  count: number;
}

console.log("StockDrop Stock Monitor Edge Function started");

serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );

    // Get environment variables
    const FMP_API_KEY = Deno.env.get("FMP_API_KEY");
    const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID");
    const ONESIGNAL_REST_API_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY");

    if (!FMP_API_KEY || !ONESIGNAL_APP_ID || !ONESIGNAL_REST_API_KEY) {
      throw new Error("Missing required environment variables");
    }

    console.log("🔄 Starting stock monitoring cycle...");

    // Step 1: Get all unique favorited stocks and their users
    const { data: favorites, error: favoritesError } = await supabaseClient
      .from("st_favorites")
      .select(
        `
        symbol,
        user_id,
        created_at
      `
      )
      .order("symbol");

    if (favoritesError) {
      throw new Error(`Failed to fetch favorites: ${favoritesError.message}`);
    }

    if (!favorites || favorites.length === 0) {
      console.log("📊 No favorite stocks found");
      return new Response(
        JSON.stringify({
          success: true,
          message: "No favorite stocks to monitor",
          processed: 0,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    console.log(`📊 Found ${favorites.length} favorite entries`);

    // Step 2: Get user settings for notification thresholds
    const { data: userSettings, error: settingsError } = await supabaseClient
      .from("st_settings")
      .select("user_id, notification_threshold");

    if (settingsError) {
      console.error("⚠️ Failed to fetch user settings:", settingsError.message);
    }

    // Create a map of user_id -> notification_threshold (default to 5% if not set)
    const userThresholds = new Map<string, number>();
    if (userSettings) {
      userSettings.forEach((setting: UserSetting) => {
        userThresholds.set(
          setting.user_id,
          setting.notification_threshold || 5
        );
      });
    }

    // Step 3: Group favorites by symbol to minimize API calls
    const symbolsToUsers = new Map<
      string,
      Array<{ userId: string; threshold: number }>
    >();
    favorites.forEach((favorite: Favorite) => {
      if (!symbolsToUsers.has(favorite.symbol)) {
        symbolsToUsers.set(favorite.symbol, []);
      }
      symbolsToUsers.get(favorite.symbol)?.push({
        userId: favorite.user_id,
        threshold: userThresholds.get(favorite.user_id) || 5,
      });
    });

    const uniqueSymbols = Array.from(symbolsToUsers.keys());
    console.log(`📈 Monitoring ${uniqueSymbols.length} unique symbols`);

    // Step 4: Fetch current stock prices from FMP API
    const stockPrices = await fetchStockPrices(uniqueSymbols, FMP_API_KEY);

    if (stockPrices.length === 0) {
      console.log("⚠️ No stock prices retrieved");
      return new Response(
        JSON.stringify({
          success: true,
          message: "No stock prices available",
          processed: 0,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    console.log(`💰 Retrieved prices for ${stockPrices.length} stocks`);

    // Step 5: Check notification limits for today
    const today = new Date().toISOString().split("T")[0];
    const { data: todayNotifications, error: notificationError } =
      await supabaseClient
        .from("st_notifications")
        .select("user_id, COUNT(*)")
        .gte("created_at", `${today}T00:00:00.000Z`)
        .lt("created_at", `${today}T23:59:59.999Z`);

    if (notificationError) {
      console.error(
        "⚠️ Failed to fetch notification counts:",
        notificationError.message
      );
    }

    // Create a map of user_id -> notification count for today
    const dailyNotificationCounts = new Map<string, number>();
    if (todayNotifications) {
      todayNotifications.forEach((record: NotificationRecord) => {
        dailyNotificationCounts.set(record.user_id, record.count || 0);
      });
    }

    // Step 6: Process alerts and send notifications
    let alertsSent = 0;
    const notifications: Notification[] = [];

    for (const stock of stockPrices) {
      const usersForStock = symbolsToUsers.get(stock.symbol);
      if (!usersForStock) continue;

      const changePercent = stock.changesPercentage || 0;

      for (const userInfo of usersForStock) {
        const { userId, threshold } = userInfo;

        // Check if stock dropped below user's threshold
        if (changePercent <= -Math.abs(threshold)) {
          // Check daily notification limit (max 5 per day)
          const userNotificationCount =
            dailyNotificationCounts.get(userId) || 0;

          if (userNotificationCount >= 5) {
            console.log(
              `🚫 User ${userId} has reached daily notification limit`
            );
            continue;
          }

          // Prepare notification
          const notification: Notification = {
            user_id: userId,
            symbol: stock.symbol,
            price: stock.price,
            change_percent: changePercent,
            threshold: threshold,
            message: `${stock.symbol} dropped ${Math.abs(changePercent).toFixed(
              2
            )}% to $${stock.price.toFixed(2)}`,
          };

          notifications.push(notification);

          // Send push notification via OneSignal
          const pushSent = await sendPushNotification(
            notification,
            ONESIGNAL_APP_ID,
            ONESIGNAL_REST_API_KEY
          );

          if (pushSent) {
            // Log notification in database
            await logNotification(supabaseClient, notification);
            alertsSent++;

            // Update daily count
            dailyNotificationCounts.set(
              userId,
              (dailyNotificationCounts.get(userId) || 0) + 1
            );
          }
        }
      }
    }

    console.log(`✅ Stock monitoring completed. Sent ${alertsSent} alerts`);

    return new Response(
      JSON.stringify({
        success: true,
        message: `Stock monitoring completed successfully`,
        processed: {
          favoriteEntries: favorites.length,
          uniqueSymbols: uniqueSymbols.length,
          stockPricesRetrieved: stockPrices.length,
          alertsSent: alertsSent,
          notifications: notifications.length,
        },
        timestamp: new Date().toISOString(),
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("❌ Error in stock monitor function:", error);

    const errorMessage =
      error instanceof Error ? error.message : "Unknown error occurred";

    return new Response(
      JSON.stringify({
        success: false,
        error: errorMessage,
        timestamp: new Date().toISOString(),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

// ==================== HELPER FUNCTIONS ====================

/**
 * Fetch stock prices from Financial Modeling Prep API
 */
async function fetchStockPrices(
  symbols: string[],
  apiKey: string
): Promise<StockPrice[]> {
  try {
    if (symbols.length === 0) return [];

    // FMP API allows multiple symbols in one request (comma-separated)
    const symbolString = symbols.join(",");
    const url = `https://financialmodelingprep.com/api/v3/quote/${symbolString}?apikey=${apiKey}`;

    console.log(`📡 Fetching prices for: ${symbolString}`);

    const response = await fetch(url);

    if (!response.ok) {
      throw new Error(
        `FMP API request failed: ${response.status} ${response.statusText}`
      );
    }

    const data = await response.json();

    if (!Array.isArray(data)) {
      console.warn("⚠️ Unexpected FMP API response format");
      return [];
    }

    // Filter out invalid data and normalize
    const validStocks: StockPrice[] = data
      .filter(
        (stock: any) => stock && stock.symbol && typeof stock.price === "number"
      )
      .map((stock: any) => ({
        symbol: stock.symbol,
        price: stock.price,
        change: stock.change || 0,
        changesPercentage: stock.changesPercentage || 0,
        volume: stock.volume || 0,
        timestamp: new Date().toISOString(),
      }));

    console.log(`💹 Successfully processed ${validStocks.length} stock prices`);
    return validStocks;
  } catch (error) {
    console.error("❌ Error fetching stock prices:", error);
    return [];
  }
}

/**
 * Send push notification via OneSignal
 */
async function sendPushNotification(
  notification: Notification,
  appId: string,
  restApiKey: string
): Promise<boolean> {
  try {
    const { user_id, symbol, message, change_percent, price } = notification;

    const pushPayload = {
      app_id: appId,
      filters: [
        { field: "tag", key: "user_id", relation: "=", value: user_id },
      ],
      headings: { en: `${symbol} Price Alert` },
      contents: { en: message },
      data: {
        type: "stock_alert",
        symbol: symbol,
        user_id: user_id,
        price: price.toString(),
        change_percent: change_percent.toString(),
        timestamp: new Date().toISOString(),
      },
      android_accent_color: "FF2196F3", // Material Blue
      small_icon: "ic_stat_stock_alert",
      large_icon: "ic_large_stock_alert",
    };

    console.log(
      `📱 Sending push notification to user ${user_id} for ${symbol}`
    );

    const response = await fetch("https://onesignal.com/api/v1/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Basic ${restApiKey}`,
      },
      body: JSON.stringify(pushPayload),
    });

    const responseData = await response.json();

    if (!response.ok) {
      console.error("❌ OneSignal API error:", responseData);
      return false;
    }

    if (responseData.errors && responseData.errors.length > 0) {
      console.error("❌ OneSignal notification errors:", responseData.errors);
      return false;
    }

    console.log(
      `✅ Push notification sent successfully. ID: ${responseData.id}`
    );
    return true;
  } catch (error) {
    console.error("❌ Error sending push notification:", error);
    return false;
  }
}

/**
 * Log notification in database for tracking and rate limiting
 */
async function logNotification(
  supabaseClient: any,
  notification: Notification
): Promise<void> {
  try {
    const { error } = await supabaseClient.from("st_notifications").insert({
      user_id: notification.user_id,
      symbol: notification.symbol,
      message: notification.message,
      price: notification.price,
      change_percent: notification.change_percent,
      threshold: notification.threshold,
      created_at: new Date().toISOString(),
    });

    if (error) {
      console.error("❌ Failed to log notification:", error);
    } else {
      console.log(`📝 Notification logged for user ${notification.user_id}`);
    }
  } catch (error) {
    console.error("❌ Error logging notification:", error);
  }
}
