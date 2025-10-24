# StockDrop Widgets Documentation

## Overview

This directory contains reusable Material 3 design components for the StockDrop app. All widgets follow consistent design patterns and integrate seamlessly with the app's services.

## Available Widgets

### 1. StockCard Widget

A comprehensive card component for displaying stock information with interactive features.

### 2. ChartWidget

An advanced charting component for displaying 5-minute intraday stock price data using fl_chart.

---

# StockCard Widget Documentation

## Features

- ✅ **Material 3 Design**: Modern cards with rounded corners and proper elevation
- ✅ **Color-coded Changes**: Red for negative, green for positive percentage changes
- ✅ **Interactive Elements**: Tap to navigate, favorite button for bookmarking
- ✅ **Responsive Layout**: Adapts to different screen sizes
- ✅ **Loading States**: Skeleton cards for better UX during data loading
- ✅ **Multiple Variants**: Regular, compact, and skeleton versions
- ✅ **Accessibility**: Proper tooltips and semantic structure

## Widget Variants

### 1. StockCard (Standard)

The main card component with full stock information display.

```dart
StockCard(
  stock: Stock(
    symbol: 'AAPL',
    name: 'Apple Inc.',
    price: 175.43,
    change: 2.15,
    changePercent: 1.24,
  ),
  isFavorited: true,
  onTap: () => Navigator.pushNamed(context, '/stock-detail'),
  onFavoritePressed: () => toggleFavorite('AAPL'),
)
```

### 2. CompactStockCard

A smaller variant for dense lists and quick overviews.

```dart
CompactStockCard(
  stock: stock,
  isFavorited: favoriteSymbols.contains(stock.symbol),
  onTap: () => navigateToDetail(stock),
  onFavoritePressed: () => toggleFavorite(stock.symbol),
)
```

### 3. StockCardSkeleton

Loading state placeholder while fetching data.

```dart
StockCardSkeleton(showFavoriteButton: true)
```

## Properties

### StockCard Properties

| Property             | Type            | Default  | Description                              |
| -------------------- | --------------- | -------- | ---------------------------------------- |
| `stock`              | `Stock`         | required | The stock data to display                |
| `onTap`              | `VoidCallback?` | `null`   | Callback when card is tapped             |
| `onFavoritePressed`  | `VoidCallback?` | `null`   | Callback when favorite button is pressed |
| `isFavorited`        | `bool`          | `false`  | Whether stock is currently favorited     |
| `showFavoriteButton` | `bool`          | `true`   | Whether to show the favorite button      |

### Stock Model Requirements

The widget expects a `Stock` object with these properties:

```dart
class Stock {
  final String symbol;        // Stock ticker (e.g., 'AAPL')
  final String name;          // Company name (e.g., 'Apple Inc.')
  final double price;         // Current price (e.g., 175.43)
  final double change;        // Price change (e.g., 2.15)
  final double changePercent; // Percentage change (e.g., 1.24)
  // ... other optional properties
}
```

## Usage Examples

### Basic Stock List

```dart
ListView.builder(
  itemCount: stocks.length,
  itemBuilder: (context, index) {
    final stock = stocks[index];
    return StockCard(
      stock: stock,
      isFavorited: favoriteSymbols.contains(stock.symbol),
      onTap: () => Navigator.pushNamed(
        context,
        '/stock-detail',
        arguments: stock,
      ),
      onFavoritePressed: () => _toggleFavorite(stock.symbol),
    );
  },
)
```

### With SupabaseService Integration

```dart
class StockListScreen extends StatefulWidget {
  @override
  _StockListScreenState createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<String> _favoriteSymbols = [];

  @override
  void initState() {
    super.initState();
    // Listen to favorites changes
    _supabaseService.getFavoritesStream().listen((favorites) {
      setState(() => _favoriteSymbols = favorites);
    });
  }

  Future<void> _toggleFavorite(String symbol) async {
    try {
      await _supabaseService.toggleFavorite(symbol);
      // Success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated favorites')),
      );
    } catch (e) {
      // Error handling
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: stocks.length,
      itemBuilder: (context, index) {
        final stock = stocks[index];
        return StockCard(
          stock: stock,
          isFavorited: _favoriteSymbols.contains(stock.symbol),
          onTap: () => _navigateToDetail(stock),
          onFavoritePressed: () => _toggleFavorite(stock.symbol),
        );
      },
    );
  }
}
```

### Loading State Example

```dart
Widget build(BuildContext context) {
  if (isLoading) {
    return ListView.builder(
      itemCount: 5, // Show 5 skeleton cards
      itemBuilder: (context, index) => StockCardSkeleton(),
    );
  }

  return ListView.builder(
    itemCount: stocks.length,
    itemBuilder: (context, index) {
      return StockCard(stock: stocks[index]);
    },
  );
}
```

### Search Results with Compact Cards

```dart
Widget buildSearchResults() {
  return ListView.builder(
    itemCount: searchResults.length,
    itemBuilder: (context, index) {
      final stock = searchResults[index];
      return CompactStockCard(
        stock: stock,
        isFavorited: favoriteSymbols.contains(stock.symbol),
        onTap: () => _selectStock(stock),
        onFavoritePressed: () => _toggleFavorite(stock.symbol),
      );
    },
  );
}
```

## Design Specifications

### Colors

- **Positive Change**: Uses `Theme.of(context).colorScheme.primary` (typically green)
- **Negative Change**: Uses `Theme.of(context).colorScheme.error` (typically red)
- **Text**: Uses appropriate Material 3 color tokens for contrast
- **Background**: Automatic based on current theme (light/dark)

### Typography

- **Stock Symbol**: `titleMedium` with bold weight
- **Company Name**: `bodySmall` with medium opacity
- **Price**: `titleMedium` with semi-bold weight
- **Change Amount**: `bodySmall` with medium weight
- **Percentage**: `bodySmall` with bold weight in colored container

### Spacing

- **Card Margin**: 16px horizontal, 4px vertical
- **Card Padding**: 16px all around
- **Internal Spacing**: 12px between sections, 2-4px between related elements
- **Border Radius**: 12px for standard cards, 8px for compact cards

### Accessibility

- **Tooltips**: Favorite button includes descriptive tooltips
- **Contrast**: All text meets WCAG AA contrast requirements
- **Touch Targets**: Minimum 44px touch areas for interactive elements
- **Semantic Structure**: Proper widget hierarchy for screen readers

## Integration with StockDrop Services

### SupabaseService

```dart
// Toggle favorite status
await _supabaseService.toggleFavorite(stock.symbol);

// Listen to favorites changes
_supabaseService.getFavoritesStream().listen((favorites) {
  // Update UI with new favorites list
});

// Check if stock is favorited
bool isFav = await _supabaseService.isFavorite(stock.symbol);
```

### ApiService

```dart
// Get stock data for cards
final stocks = await _apiService.getLosers();
final searchResults = await _apiService.searchStocks(query);
```

### PushService

```dart
// Register for notifications when adding favorites
await _pushService.registerUser();
```

## Customization

### Hiding Favorite Button

```dart
StockCard(
  stock: stock,
  showFavoriteButton: false, // Hides the favorite button
  onTap: () => navigateToDetail(stock),
)
```

### Custom Styling

The widget automatically adapts to your app's theme. To customize:

1. **Colors**: Modify your app's `ColorScheme`
2. **Typography**: Update your app's `TextTheme`
3. **Shapes**: Adjust `ShapeTheme` for different border radius

### Performance Considerations

- **ListView.builder**: Always use for large lists
- **Skeleton Loading**: Show during data fetching for better UX
- **Image Caching**: If adding company logos, implement proper caching
- **State Management**: Consider using Provider/Riverpod for favorites state

## Error Handling

```dart
// Handle favorite toggle errors
try {
  await _supabaseService.toggleFavorite(symbol);
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to update favorites: $e'),
        backgroundColor: Theme.of(context).colorScheme.error,
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => _toggleFavorite(symbol),
        ),
      ),
    );
  }
}
```

## Best Practices

1. **Always handle loading states** with skeleton cards
2. **Provide user feedback** for favorite actions
3. **Use appropriate card variant** based on context
4. **Handle errors gracefully** with retry options
5. **Maintain favorites state** across navigation
6. **Test with different screen sizes** and orientations
7. **Follow Material 3 guidelines** for consistency

---

# ChartWidget Documentation

## Overview

The `ChartWidget` is a comprehensive charting component that displays 5-minute intraday stock price data using the fl_chart library. It fetches real-time data from the Financial Modeling Prep API and provides an interactive, Material 3 designed chart experience.

## Features

- ✅ **Real-time Data**: Fetches 5-minute intraday data from FMP API
- ✅ **Material 3 Design**: Consistent with app theming and design language
- ✅ **Interactive Charts**: Touch support with tooltips and data point highlighting
- ✅ **Loading States**: Elegant loading indicators with progress feedback
- ✅ **Error Handling**: Comprehensive error states with retry functionality
- ✅ **Empty Data Handling**: Graceful handling of stocks with no chart data
- ✅ **Performance Optimized**: Limits data points for smooth rendering
- ✅ **Gradient Fill**: Beautiful gradient fill under the price line
- ✅ **Responsive Design**: Adapts to different screen sizes and orientations

## Widget Variants

### 1. ChartWidget (Standard)

The main chart component with full features and customization options.

```dart
ChartWidget(
  symbol: 'AAPL',
  height: 300,
  lineColor: Colors.blue,
  showVolume: false,
)
```

### 2. CompactChartWidget

A simplified version for smaller spaces and overview displays.

```dart
CompactChartWidget(
  symbol: 'AAPL',
  height: 150,
  lineColor: Colors.green,
)
```

## Properties

### ChartWidget Properties

| Property     | Type     | Default  | Description                                   |
| ------------ | -------- | -------- | --------------------------------------------- |
| `symbol`     | `String` | required | Stock symbol to display chart for             |
| `height`     | `double` | `300`    | Height of the chart widget                    |
| `showVolume` | `bool`   | `false`  | Whether to show volume indicator              |
| `lineColor`  | `Color?` | `null`   | Custom line color (defaults to theme primary) |

## Usage Examples

### Basic Chart Display

```dart
ChartWidget(
  symbol: 'AAPL',
  height: 350,
)
```

### Custom Styled Chart

```dart
ChartWidget(
  symbol: 'TSLA',
  height: 300,
  lineColor: stock.changePercent >= 0 ? Colors.green : Colors.red,
)
```

### In a Stock Detail Screen

```dart
class StockDetailScreen extends StatelessWidget {
  final Stock stock;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(stock.symbol)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Stock info card
            StockCard(stock: stock),

            const SizedBox(height: 16),

            // Price chart
            ChartWidget(
              symbol: stock.symbol,
              height: 400,
              lineColor: stock.changePercent >= 0
                  ? Colors.green
                  : Colors.red,
            ),

            // Additional stock details...
          ],
        ),
      ),
    );
  }
}
```

### Grid of Multiple Charts

```dart
GridView.builder(
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 1.2,
  ),
  itemCount: symbols.length,
  itemBuilder: (context, index) {
    return CompactChartWidget(
      symbol: symbols[index],
      height: 120,
    );
  },
)
```

## Data Integration

### Financial Modeling Prep API

The widget automatically fetches data from the FMP API endpoint:

```
https://financialmodelingprep.com/api/v3/historical-chart/5min/{SYMBOL}?apikey={API_KEY}
```

### Data Processing

- **Data Limiting**: Displays last 100 data points for optimal performance
- **Time Sorting**: Automatically sorts data chronologically
- **Price Scaling**: Adds 2% padding to min/max for better visualization
- **Error Handling**: Graceful handling of API failures and invalid data

### Environment Setup

Ensure your `.env` file contains:

```env
FMP_API_KEY=your_financial_modeling_prep_api_key
```

## Chart Features

### Interactive Elements

- **Touch Tooltips**: Show price and time on tap
- **Price Scaling**: Automatic Y-axis scaling based on data range
- **Time Labels**: Formatted time labels on X-axis (HH:MM format)
- **Grid Lines**: Subtle horizontal grid lines for easier reading

### Visual Design

- **Gradient Fill**: Semi-transparent gradient under the price line
- **Smooth Curves**: Curved line rendering for better visual appeal
- **Material Colors**: Uses theme color scheme for consistency
- **Border Styling**: Subtle borders matching Material 3 design

### Performance Considerations

- **Data Limiting**: Maximum 100 data points to ensure smooth rendering
- **Lazy Loading**: Data only fetched when widget is built
- **Memory Efficient**: Properly disposes of resources and HTTP connections
- **Caching**: Considers implementing local caching for frequently viewed symbols

## Error States

### Loading State

Shows circular progress indicator with loading message.

### Error State

Displays error icon, message, and retry button for failed API calls.

### Empty Data State

Shows appropriate message when no chart data is available for the symbol.

### Network Error Handling

```dart
try {
  final response = await http.get(url);
  // Process response...
} catch (e) {
  setState(() {
    _errorMessage = 'Failed to load chart data: $e';
  });
}
```

## Customization

### Theme Integration

The widget automatically adapts to your app's theme:

```dart
// Colors are automatically derived from theme
final lineColor = widget.lineColor ?? colorScheme.primary;
final gridColor = colorScheme.outline.withOpacity(0.1);
final textColor = colorScheme.onSurfaceVariant;
```

### Custom Styling

```dart
ChartWidget(
  symbol: 'AAPL',
  height: 300,
  lineColor: Colors.purple, // Custom line color
)
```

## Best Practices

1. **Always provide symbol**: Ensure valid stock symbols are passed
2. **Handle loading states**: Show appropriate feedback during data loading
3. **Error recovery**: Implement retry mechanisms for failed requests
4. **Performance**: Limit the number of simultaneous chart widgets
5. **Caching**: Consider implementing data caching for better UX
6. **Accessibility**: Ensure charts are accessible with proper semantic labels
7. **Testing**: Test with various symbols including invalid ones

## Dependencies

- `flutter/material.dart` - Core Material Design components
- `fl_chart` - Advanced charting library for Flutter
- `http` - HTTP client for API requests
- `flutter_dotenv` - Environment variable management

## File Structure

```
lib/
  widgets/
    chart_widget.dart              # Main chart widget
    chart_widget_examples.dart     # Usage examples
    stock_card.dart               # Stock card widget
    README.md                     # This documentation
  models/
    stock.dart                    # Stock data model
  services/
    api_service.dart              # API service integration
```

## Troubleshooting

### Common Issues

1. **"FMP_API_KEY not found"**

   - Ensure `.env` file contains valid API key
   - Check that `flutter_dotenv` is properly configured

2. **"No chart data available"**

   - Verify stock symbol is valid and actively traded
   - Check if symbol has 5-minute intraday data available

3. **"API request failed"**

   - Verify internet connection
   - Check API key validity and quota limits
   - Ensure FMP API service is operational

4. **Performance issues with multiple charts**
   - Limit number of simultaneous chart widgets
   - Consider lazy loading for off-screen charts
   - Implement data caching mechanisms

### Debug Mode

Add debug logging:

```dart
debugPrint('📈 Fetching 5min chart data for ${widget.symbol}');
debugPrint('✅ Loaded ${limitedData.length} chart points');
```

The ChartWidget provides a comprehensive solution for displaying stock price charts in your StockDrop app, with robust error handling, beautiful Material 3 design, and excellent performance characteristics.

## Dependencies

- `flutter/material.dart` - Core Material Design components
- `../models/stock.dart` - Stock data model
- `../services/supabase_service.dart` - Database operations (optional)

## File Structure

```
lib/
  widgets/
    stock_card.dart              # Main widget file
    stock_card_examples.dart     # Usage examples
  models/
    stock.dart                   # Stock data model
  services/
    supabase_service.dart        # Database service
```

The StockCard widget is designed to be the primary component for displaying stock information throughout the StockDrop app, providing a consistent and polished user experience.
