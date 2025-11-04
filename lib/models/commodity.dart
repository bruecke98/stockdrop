/// Commodity model class for StockDrop app
/// Represents commodity price data (gold, silver, oil) with current price and market information
class Commodity {
  final String symbol;
  final String name;
  final double price;
  final double change;
  final double changePercent;
  final String currency;
  final double? dayHigh;
  final double? dayLow;
  final double? open;
  final double? previousClose;
  final DateTime? lastUpdated;
  final String type; // 'gold', 'silver', 'oil'

  Commodity({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.type,
    this.currency = 'USD',
    this.dayHigh,
    this.dayLow,
    this.open,
    this.previousClose,
    this.lastUpdated,
  });

  /// Create Commodity from JSON (from FMP API quote endpoint)
  factory Commodity.fromQuoteJson(Map<String, dynamic> json, String type) {
    return Commodity(
      symbol: json['symbol']?.toString() ?? '',
      name:
          json['name']?.toString() ?? _getNameFromSymbol(json['symbol'] ?? ''),
      price: (json['price'] ?? 0.0).toDouble(),
      change: (json['change'] ?? 0.0).toDouble(),
      changePercent: (json['changesPercentage'] ?? 0.0).toDouble(),
      type: type,
      currency: 'USD',
      dayHigh: json['dayHigh']?.toDouble(),
      dayLow: json['dayLow']?.toDouble(),
      open: json['open']?.toDouble(),
      previousClose: json['previousClose']?.toDouble(),
      lastUpdated: DateTime.now(),
    );
  }

  /// Create Commodity from historical JSON data
  factory Commodity.fromHistoricalJson(Map<String, dynamic> json, String type) {
    return Commodity(
      symbol: type.toUpperCase(),
      name: _getNameFromType(type),
      price: (json['close'] ?? 0.0).toDouble(),
      change: 0.0, // Historical data doesn't include change
      changePercent: 0.0, // Will be calculated separately
      type: type,
      currency: 'USD',
      dayHigh: json['high']?.toDouble(),
      dayLow: json['low']?.toDouble(),
      open: json['open']?.toDouble(),
    );
  }

  /// Get commodity name from symbol
  static String _getNameFromSymbol(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'GCUSD':
        return 'Gold';
      case 'SIUSD':
        return 'Silver';
      case 'BZUSD':
        return 'Crude Oil';
      default:
        return symbol;
    }
  }

  /// Get commodity name from type
  static String _getNameFromType(String type) {
    switch (type.toLowerCase()) {
      case 'gold':
        return 'Gold';
      case 'silver':
        return 'Silver';
      case 'oil':
        return 'Crude Oil';
      default:
        return type;
    }
  }

  /// Get formatted price with proper currency symbol
  String get formattedPrice {
    if (price >= 1000) {
      return '\$${price.toStringAsFixed(0)}';
    } else if (price >= 100) {
      return '\$${price.toStringAsFixed(1)}';
    } else {
      return '\$${price.toStringAsFixed(2)}';
    }
  }

  /// Get formatted change with + or - prefix
  String get formattedChange {
    final sign = change >= 0 ? '+' : '';
    return '$sign\$${change.toStringAsFixed(2)}';
  }

  /// Get formatted change percentage with + or - prefix
  String get formattedChangePercent {
    final sign = changePercent >= 0 ? '+' : '';
    return '$sign${changePercent.toStringAsFixed(2)}%';
  }

  /// Check if commodity is gaining (positive change)
  bool get isGaining => changePercent >= 0;

  /// Get trend direction
  String get trend {
    if (changePercent > 0) return 'up';
    if (changePercent < 0) return 'down';
    return 'neutral';
  }

  /// Get appropriate icon based on commodity type
  String get iconPath {
    switch (type.toLowerCase()) {
      case 'gold':
        return 'assets/icons/gold.png';
      case 'silver':
        return 'assets/icons/silver.png';
      case 'oil':
        return 'assets/icons/oil.png';
      default:
        return 'assets/icons/commodity.png';
    }
  }

  /// Get commodity symbol for API calls
  String get apiSymbol {
    switch (type.toLowerCase()) {
      case 'gold':
        return 'GCUSD';
      case 'silver':
        return 'SIUSD';
      case 'oil':
        return 'BZUSD';
      default:
        return symbol;
    }
  }

  /// Get display color based on commodity type
  int get primaryColor {
    switch (type.toLowerCase()) {
      case 'gold':
        return 0xFFFFD700; // Gold
      case 'silver':
        return 0xFFC0C0C0; // Silver
      case 'oil':
        return 0xFF1E1E1E; // Dark for oil
      default:
        return 0xFF6200EE; // Default purple
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'name': name,
      'price': price,
      'change': change,
      'changePercent': changePercent,
      'type': type,
      'currency': currency,
      'dayHigh': dayHigh,
      'dayLow': dayLow,
      'open': open,
      'previousClose': previousClose,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Commodity($name: $formattedPrice $formattedChangePercent)';
  }
}

/// Historical price point for commodity charts
class CommodityHistoricalPoint {
  final String date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double? volume;

  CommodityHistoricalPoint({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume,
  });

  factory CommodityHistoricalPoint.fromJson(Map<String, dynamic> json) {
    return CommodityHistoricalPoint(
      date: json['date']?.toString() ?? '',
      open: (json['open'] ?? 0.0).toDouble(),
      high: (json['high'] ?? 0.0).toDouble(),
      low: (json['low'] ?? 0.0).toDouble(),
      close: (json['close'] ?? 0.0).toDouble(),
      volume: json['volume']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'volume': volume,
    };
  }
}

/// Comprehensive commodity data with current price and historical data
class CommodityData {
  final Commodity current;
  final List<CommodityHistoricalPoint> historical;

  CommodityData({required this.current, required this.historical});

  /// Calculate price change from historical data
  double get historicalChangePercent {
    if (historical.isEmpty) return 0.0;

    final firstPrice = historical.first.close;
    final lastPrice = current.price;

    if (firstPrice == 0) return 0.0;

    return ((lastPrice - firstPrice) / firstPrice) * 100;
  }

  /// Get formatted historical change percentage
  String get formattedHistoricalChangePercent {
    final change = historicalChangePercent;
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(2)}%';
  }

  Map<String, dynamic> toJson() {
    return {
      'current': current.toJson(),
      'historical': historical.map((point) => point.toJson()).toList(),
    };
  }
}
