# StockDrop Edge Function Deployment Guide

## Overview

The `stock-monitor` Edge Function provides automated stock price monitoring with push notifications for the StockDrop app.

## Function Features

- ✅ **Real-time Monitoring**: Fetches current stock prices from Financial Modeling Prep API
- ✅ **Smart Notifications**: Sends push notifications when stocks drop below user thresholds
- ✅ **Rate Limiting**: Maximum 5 notifications per user per day
- ✅ **Batch Processing**: Efficiently processes multiple stocks in single API calls
- ✅ **Error Handling**: Comprehensive error handling and logging
- ✅ **User Settings**: Respects individual notification thresholds

## Prerequisites

### 1. Supabase Project Setup

- Supabase project with authentication enabled
- Database tables: `st_favorites`, `st_settings`, `st_notifications`
- Run migration: `supabase/migrations/20241217_create_notifications_table.sql`

### 2. API Keys Required

- **Financial Modeling Prep API Key**: Get from [financialmodelingprep.com](https://financialmodelingprep.com/developer/docs)
- **OneSignal App ID**: From your OneSignal app dashboard
- **OneSignal REST API Key**: From OneSignal Settings > Keys & IDs

### 3. Environment Variables

Set these in your Supabase project dashboard (Settings > Edge Functions):

```env
FMP_API_KEY=your_financial_modeling_prep_api_key
ONESIGNAL_APP_ID=your_onesignal_app_id
ONESIGNAL_REST_API_KEY=your_onesignal_rest_api_key
```

## Deployment Steps

### 1. Install Supabase CLI

```powershell
# Install via npm
npm install -g supabase

# Or via chocolatey
choco install supabase
```

### 2. Login to Supabase

```powershell
supabase login
```

### 3. Link Your Project

```powershell
# In your project root directory
supabase link --project-ref YOUR_PROJECT_ID
```

### 4. Deploy the Function

```powershell
# Deploy the stock-monitor function
supabase functions deploy stock-monitor
```

### 5. Set Environment Variables

```powershell
# Set your API keys
supabase secrets set FMP_API_KEY=your_api_key_here
supabase secrets set ONESIGNAL_APP_ID=your_app_id_here
supabase secrets set ONESIGNAL_REST_API_KEY=your_rest_api_key_here
```

## Testing the Function

### Manual Test

```powershell
# Test the function manually
curl -X POST "https://YOUR_PROJECT_ID.supabase.co/functions/v1/stock-monitor" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json"
```

### Expected Response

```json
{
  "success": true,
  "message": "Stock monitoring completed successfully",
  "processed": {
    "favoriteEntries": 5,
    "uniqueSymbols": 3,
    "stockPricesRetrieved": 3,
    "alertsSent": 1,
    "notifications": 1
  },
  "timestamp": "2024-12-17T10:30:00.000Z"
}
```

## Scheduling Options

### Option 1: External Cron (Recommended)

Use a service like GitHub Actions, Vercel Cron, or Uptime Robot:

```yaml
# .github/workflows/stock-monitor.yml
name: Stock Monitor
on:
  schedule:
    - cron: "*/5 * * * *" # Every 5 minutes
jobs:
  monitor:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Stock Monitor
        run: |
          curl -X POST "${{ secrets.SUPABASE_URL }}/functions/v1/stock-monitor" \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_ANON_KEY }}"
```

### Option 2: Database Triggers

Create a recurring database event (if supported by your hosting).

### Option 3: Client-side Scheduling

Call from your Flutter app periodically (not recommended for production).

## Monitoring & Logs

### View Function Logs

```powershell
# View real-time logs
supabase functions logs stock-monitor

# View specific time range
supabase functions logs stock-monitor --start="2024-12-17T10:00:00Z"
```

### Monitor Database

Check the `st_notifications` table to see sent notifications:

```sql
SELECT
  symbol,
  COUNT(*) as notification_count,
  DATE(created_at) as date
FROM st_notifications
GROUP BY symbol, DATE(created_at)
ORDER BY date DESC, notification_count DESC;
```

## Troubleshooting

### Common Issues

1. **"Missing required environment variables"**

   - Ensure all secrets are set: `supabase secrets list`

2. **"Failed to fetch favorites"**

   - Check database connectivity and table permissions
   - Verify RLS policies allow service_role access

3. **"FMP API request failed"**

   - Verify your Financial Modeling Prep API key
   - Check API quota limits

4. **"OneSignal API error"**
   - Verify OneSignal credentials
   - Check app configuration

### Debug Mode

Add debug logging by setting:

```env
DEBUG=true
```

## Performance Considerations

- **API Limits**: FMP API typically allows 250 calls/day on free tier
- **Batch Requests**: Function groups symbols to minimize API calls
- **Rate Limiting**: Built-in 5 notifications/user/day limit
- **Execution Time**: Function typically completes in 2-5 seconds

## Security

- ✅ Environment variables stored securely in Supabase
- ✅ Row Level Security on all database tables
- ✅ OneSignal user targeting by user_id tags
- ✅ No sensitive data in logs or responses

## Next Steps

1. **Deploy the function**: Follow deployment steps above
2. **Set up scheduling**: Choose a scheduling option
3. **Test with real data**: Add some favorite stocks and monitor logs
4. **Monitor performance**: Check logs and database for any issues

## Support

For issues:

1. Check Supabase function logs
2. Verify environment variables
3. Test API endpoints manually
4. Check database permissions and data

The function is designed to be robust and handle errors gracefully, logging all issues for debugging.
