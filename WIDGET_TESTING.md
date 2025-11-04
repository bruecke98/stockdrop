# Testing the Android Home Screen Widget

## Steps to Test the Widget

### 1. Build and Install the App

```bash
flutter build apk --debug
flutter install
```

### 2. Add Widget to Home Screen

1. **Long press** on your Android home screen
2. Select **"Widgets"** from the menu
3. Look for **"StockDrop"** in the widget list
4. Drag the **"Top Decline Stock"** widget to your home screen
5. The widget should appear and start loading

### 3. What You Should See

#### Initial State:

- Widget shows "Loading..."
- After a few seconds, it should display demo stock data

#### Expected Display:

- **Stock Symbol**: e.g., "AAPL"
- **Stock Price**: e.g., "$150.25"
- **Change Percentage**: e.g., "-2.3%" (in red for declines)

### 4. Widget Features

#### Interactive Elements:

- **Tap the stock symbol**: Opens the main StockDrop app
- **Tap the refresh icon**: Manually refreshes the widget data
- **Auto-refresh**: Widget updates every 30 minutes automatically

#### Current Behavior:

- Shows **demo data** initially (AAPL, TSLA, or NVDA with fake declining percentages)
- Fallback to demo data if API calls fail
- Real API integration will work once API key is properly configured

### 5. Troubleshooting

#### Widget Not Appearing:

- Make sure you built and installed the latest version
- Check that the widget provider is registered in AndroidManifest.xml
- Try restarting the launcher app

#### Widget Shows "Error":

- This is expected if no API key is configured
- Widget should still show demo data as fallback

#### Widget Not Updating:

- Try manually refreshing with the refresh button
- Check device internet connection
- Widget logs can be viewed with: `adb logcat | grep StockWidget`

### 6. Next Steps for Real Data

To get real stock data instead of demo data:

1. The Flutter app needs to run at least once to send the API key to Android
2. Or manually configure the API key in the Android widget provider
3. Ensure proper internet permissions are set (already done)

### 7. Widget Configuration

Current widget settings:

- **Size**: 4x2 cells (can be resized)
- **Update interval**: 30 minutes
- **Data source**: Demo data (fallback to prevent errors)
- **Theme**: Adapts to system theme

The widget is now ready for testing! It should display demo stock data and provide a working home screen widget experience.
