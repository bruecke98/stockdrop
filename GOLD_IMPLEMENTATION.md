# Gold Commodity Tracking - Implementation Guide

This guide shows how to implement gold commodity tracking using the two Financial Modeling Prep API endpoints in your StockDrop Flutter app.

## API Endpoints Used

1. **Quote Endpoint**: `https://financialmodelingprep.com/api/v3/quote/GCUSD?apikey=YOUR_API_KEY`

   - Provides real-time gold price data
   - Returns current price, change, and percentage change

2. **Historical Light Endpoint**: `https://financialmodelingprep.com/api/v3/historical-price-eod/light?symbol=GCUSD&apikey=YOUR_API_KEY`
   - Provides simple historical price data
   - Lightweight endpoint for basic price tracking

## Components Created

### 1. Gold Model (`lib/models/gold.dart`)

The `Gold` class represents gold commodity data with properties like:

- `symbol`: Commodity symbol (GCUSD)
- `name`: Display name (Gold Commodity)
- `price`: Current price in USD
- `change`: Price change amount
- `changePercent`: Percentage change
- Additional market data (high, low, open, etc.)

```dart
// Example usage
final gold = Gold.fromQuoteJson(apiResponse);
print(gold.formattedPrice); // $2,025.50
print(gold.formattedChangePercent); // +1.25%
```

### 2. API Service Methods (`lib/services/api_service.dart`)

Added three new methods to handle gold data:

#### `getGoldPrice()`

Fetches real-time gold price using the quote endpoint.

```dart
final apiService = ApiService();
final gold = await apiService.getGoldPrice();
if (gold != null) {
  print('Gold price: ${gold.formattedPrice}');
}
```

#### `getGoldPriceLight()`

Fetches gold price using the lighter historical endpoint.

```dart
final gold = await apiService.getGoldPriceLight();
```

#### `getComprehensiveGoldData()`

Attempts quote endpoint first, falls back to light endpoint.

```dart
// Recommended method - handles fallbacks automatically
final gold = await apiService.getComprehensiveGoldData();
```

#### `getGoldHistoricalData()`

Fetches historical gold price data for charting.

```dart
final historicalData = await apiService.getGoldHistoricalData(
  period: '1month', // '1day', '5day', '1month', '3month', '6month', '1year', '5year'
);
```

### 3. Gold Card Widget (`lib/widgets/gold_card.dart`)

A Material 3 designed card that displays current gold price information.

#### Features:

- ✅ Real-time gold price display
- ✅ Color-coded price changes (green/red)
- ✅ Loading states with skeleton UI
- ✅ Error handling with retry functionality
- ✅ Tap callbacks for navigation
- ✅ Compact and full display modes

#### Basic Usage:

```dart
import '../widgets/gold_card.dart';

// Full card
GoldCard(
  onTap: () => Navigator.pushNamed(context, '/gold-details'),
)

// Compact card
GoldCard(
  isCompact: true,
  margin: EdgeInsets.all(8),
  onTap: () => _showGoldDetails(),
)

// Loading skeleton
GoldCardSkeleton()
```

### 4. Gold Chart Widget (`lib/widgets/gold_chart_widget.dart`)

An interactive chart widget for displaying gold price history using fl_chart.

#### Features:

- ✅ Interactive line charts with touch support
- ✅ Multiple time period selection (1D, 5D, 1M, 3M, 6M, 1Y, 5Y)
- ✅ Material 3 design with gradient fills
- ✅ Loading states and error handling
- ✅ Price tooltips on touch
- ✅ Responsive design

#### Basic Usage:

```dart
import '../widgets/gold_chart_widget.dart';

// Full chart with period selector
GoldChartWidget(
  height: 300,
  showPeriodSelector: true,
  initialPeriod: '1month',
)

// Compact chart
CompactGoldChart(
  height: 150,
  lineColor: Colors.amber,
)
```

## Integration Examples

### 1. Add to Home Screen

```dart
// In your home screen build method
Column(
  children: [
    // Existing content
    _buildFilterPanel(theme),

    // Add gold card
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commodities',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          GoldCard(
            onTap: () => Navigator.pushNamed(context, '/gold'),
          ),
        ],
      ),
    ),

    // Existing stock list
    Expanded(child: _buildStockList()),
  ],
)
```

### 2. Add to Navigation

```dart
// Add gold screen to navigation
final List<Widget> _screens = [
  const HomeScreen(),
  const SearchScreen(),
  const FavoritesScreen(),
  const GoldExampleScreen(), // Add this
  const SettingsScreen(),
];

final List<BottomNavigationBarItem> _navigationItems = [
  // Existing items...
  const BottomNavigationBarItem(
    icon: Icon(Icons.toll_outlined),
    activeIcon: Icon(Icons.toll),
    label: 'Gold',
  ),
  // More items...
];
```

### 3. Create Gold Detail Screen

```dart
class GoldDetailScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gold Analysis')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Current price card
            const GoldCard(),

            const SizedBox(height: 16),

            // Historical chart
            const GoldChartWidget(
              height: 350,
              showPeriodSelector: true,
            ),

            // Additional analysis widgets...
          ],
        ),
      ),
    );
  }
}
```

### 4. Dashboard Overview

```dart
// Create a dashboard with multiple commodities
GridView.count(
  crossAxisCount: 2,
  children: [
    // Gold card
    Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Text('Gold', style: theme.textTheme.titleSmall),
            SizedBox(height: 8),
            Expanded(
              child: GoldCard(
                isCompact: true,
                margin: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    ),

    // Other commodities can be added here...
  ],
)
```

## Error Handling

All components include comprehensive error handling:

```dart
try {
  final gold = await apiService.getGoldPrice();
  // Handle success
} on ApiException catch (e) {
  if (e.isRateLimited) {
    // Handle rate limiting
  } else if (e.isAuthError) {
    // Handle authentication errors
  } else {
    // Handle other API errors
  }
} catch (e) {
  // Handle general errors
}
```

## Environment Setup

Make sure your `.env` file includes the FMP API key:

```env
FMP_API_KEY=your_financial_modeling_prep_api_key_here
```

## Dependencies

These components use the following dependencies (already in pubspec.yaml):

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.0.0
  fl_chart: ^0.68.0
  flutter_dotenv: ^5.1.0
```

## Example Screen

Check out `lib/screens/gold_example_screen.dart` for a complete implementation showing:

- Gold price cards in different configurations
- Interactive charts with period selection
- Feature showcase
- Grid layouts for dashboard views
- Loading and error states

## Performance Considerations

1. **API Rate Limiting**: The FMP API has rate limits. Consider implementing caching.
2. **Chart Performance**: Large datasets may impact performance. The chart automatically limits data points.
3. **Memory Usage**: Dispose of unused widgets and clear data when appropriate.
4. **Network Handling**: All API calls include proper error handling and retry mechanisms.

## Next Steps

1. **Caching**: Implement local storage for gold data to reduce API calls
2. **Notifications**: Add price alerts for significant gold price changes
3. **Multiple Commodities**: Extend the pattern to support silver, oil, etc.
4. **Advanced Analytics**: Add technical indicators and market analysis
5. **Watchlists**: Allow users to track multiple commodities

## Troubleshooting

### Common Issues:

1. **API Key Issues**: Ensure your FMP API key is valid and in the `.env` file
2. **Network Errors**: Check internet connectivity and API endpoint availability
3. **Chart Not Loading**: Verify fl_chart dependency and ensure data is not empty
4. **Build Errors**: Run `flutter pub get` to ensure all dependencies are installed

### Debug Mode:

Enable debug prints in the API service to see detailed request/response logs:

```dart
// In api_service.dart, debug prints show:
// 🥇 Fetching current gold price...
// ✅ Gold price fetched: $2,025.50 (+1.25%)
// ❌ Error fetching gold price: [error details]
```

This implementation provides a solid foundation for gold commodity tracking in your StockDrop app with professional-grade components and comprehensive error handling.
