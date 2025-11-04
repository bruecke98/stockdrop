# StockDrop Top Decline Widget

This widget shows the stock with the most decline today, perfect for keeping track of market movements directly from your Android home screen.

## Features

- 📉 **Real-time Data**: Shows the stock with the biggest percentage decline today
- 🔄 **Auto-refresh**: Updates every 30 minutes to keep data current
- 📱 **Multiple Sizes**: Available in standard and compact sizes
- 🎯 **Quick Access**: Tap to open the full StockDrop app
- 🌙 **Theme Support**: Adapts to your system's light/dark theme

## Widget Components

### 1. TopDeclineWidget

The main widget component that can be used within your Flutter app.

```dart
// Standard size widget
TopDeclineWidget(
  height: 120,
  padding: EdgeInsets.all(16),
  onTap: () => Navigator.pushNamed(context, '/detail'),
)

// Compact version
CompactTopDeclineWidget(
  onTap: () => print('Stock tapped!'),
)
```

### 2. HomeScreenWidgetApp

A standalone app specifically designed for Android home screen widgets.

## Android Home Screen Widget Setup

### Adding the Widget to Your Home Screen

1. **Long press** on your Android home screen
2. Select **"Widgets"** from the menu
3. Find **"StockDrop"** in the widget list
4. Drag the **"Top Decline Stock"** widget to your home screen
5. The widget will start loading the latest stock data

### Widget Features on Android

- **Auto-update**: Refreshes every 30 minutes
- **Tap to open**: Taps the stock symbol to open the main app
- **Manual refresh**: Tap the refresh icon to update immediately
- **Responsive design**: Adapts to different widget sizes

## Technical Implementation

### Files Created

#### Flutter Widgets

- `lib/widgets/top_decline_widget.dart` - Main widget component
- `lib/widgets/home_screen_widget.dart` - Standalone widget app

#### Android Configuration

- `android/app/src/main/res/xml/stock_widget_info.xml` - Widget configuration
- `android/app/src/main/res/layout/stock_widget.xml` - Android layout
- `android/app/src/main/kotlin/.../StockWidgetProvider.kt` - Widget provider
- Various drawable resources and strings

### Data Source

The widget uses a new `ApiService.getTopDecliningStocks()` method to fetch stocks:

- Gets all available stocks from the screener (lower thresholds for more results)
- Sorts them by percentage change (most declining first)
- Returns the top stock regardless of decline percentage
- Displays declining stocks with red color and down arrow, rising stocks with blue color and up arrow

### Customization

You can customize the widget by modifying:

- **Update frequency**: Change `android:updatePeriodMillis` in `stock_widget_info.xml`
- **Size**: Adjust `android:minWidth` and `android:minHeight`
- **Appearance**: Modify layouts and drawable resources
- **Data criteria**: Update the filtering logic in `ApiService.getLosers()`

## Usage in Your App

The widget is already integrated into your home screen. You can also use it elsewhere:

```dart
import 'package:your_app/widgets/top_decline_widget.dart';

// In your widget tree
Column(
  children: [
    TopDeclineWidget(), // Shows the most declining stock
    // ... other widgets
  ],
)
```

## Troubleshooting

### Widget Not Updating

- Check your internet connection
- Verify API key is properly configured
- Try manually refreshing the widget

### Widget Shows "Loading..."

- Ensure your app has internet permissions
- Check if the API service is responding
- Verify the stock market is open (may show no data on weekends/holidays)

### Widget Not Appearing in Widget List

- Make sure you've built the app with the widget configuration
- Check that the widget provider is properly registered in AndroidManifest.xml

## Future Enhancements

- [ ] Multiple widget sizes (1x1, 2x1, 2x2)
- [ ] Configurable update intervals
- [ ] Widget configuration activity
- [ ] Multiple stock display options
- [ ] Dark/light theme preferences
- [ ] Interactive charts in widget
