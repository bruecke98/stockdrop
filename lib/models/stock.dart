/// Stock model class for StockDrop app
/// Represents a stock with its current price and market data
class Stock {
  final String symbol;
  final String name;
  final double price;
  final double change;
  final double changePercent;
  final String? currency;
  final int? volume;
  final double? marketCap;
  final double? dayHigh;
  final double? dayLow;
  final double? yearHigh;
  final double? yearLow;
  final double? priceAvg50;
  final double? priceAvg200;
  final String? exchange;
  final double? open;
  final double? previousClose;
  final DateTime? lastUpdated;
  final int? timestamp;

  Stock({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change,
    required this.changePercent,
    this.currency,
    this.volume,
    this.marketCap,
    this.dayHigh,
    this.dayLow,
    this.yearHigh,
    this.yearLow,
    this.priceAvg50,
    this.priceAvg200,
    this.exchange,
    this.open,
    this.previousClose,
    this.lastUpdated,
    this.timestamp,
  });

  /// Create Stock from JSON (typically from API response)
  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      symbol: json['symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: _parseDouble(json['price']) ?? 0.0,
      change: _parseDouble(json['change']) ?? 0.0,
      changePercent:
          _parseDouble(json['changePercentage']) ??
          _parseDouble(json['changePercent']) ??
          0.0,
      currency: json['currency']?.toString(),
      volume: _parseInt(json['volume']),
      marketCap: _parseDouble(json['marketCap']),
      dayHigh: _parseDouble(json['dayHigh']),
      dayLow: _parseDouble(json['dayLow']),
      yearHigh: _parseDouble(json['yearHigh']),
      yearLow: _parseDouble(json['yearLow']),
      priceAvg50: _parseDouble(json['priceAvg50']),
      priceAvg200: _parseDouble(json['priceAvg200']),
      exchange: json['exchange']?.toString(),
      open: _parseDouble(json['open']),
      previousClose: _parseDouble(json['previousClose']),
      timestamp: _parseInt(json['timestamp']),
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'].toString())
          : (json['timestamp'] != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    (_parseInt(json['timestamp']) ?? 0) * 1000,
                  )
                : null),
    );
  }

  /// Convert Stock to JSON
  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'name': name,
      'price': price,
      'change': change,
      'changePercent': changePercent,
      'currency': currency,
      'volume': volume,
      'marketCap': marketCap,
      'dayHigh': dayHigh,
      'dayLow': dayLow,
      'yearHigh': yearHigh,
      'yearLow': yearLow,
      'priceAvg50': priceAvg50,
      'priceAvg200': priceAvg200,
      'exchange': exchange,
      'open': open,
      'previousClose': previousClose,
      'timestamp': timestamp,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  /// Helper method to safely parse double from dynamic value
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Helper method to safely parse int from dynamic value
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Check if stock price is trending up
  bool get isPositive => change > 0;

  /// Check if stock price is trending down
  bool get isNegative => change < 0;

  /// Get formatted price string
  String get formattedPrice {
    return '\$${price.toStringAsFixed(2)}';
  }

  /// Get formatted change string with sign
  String get formattedChange {
    final sign = change >= 0 ? '+' : '';
    return '$sign\$${change.toStringAsFixed(2)}';
  }

  /// Get formatted change percent string with sign
  String get formattedChangePercent {
    final sign = changePercent >= 0 ? '+' : '';
    return '$sign${changePercent.toStringAsFixed(2)}%';
  }

  /// Get formatted market cap string
  String get formattedMarketCap {
    if (marketCap == null) return 'N/A';

    if (marketCap! >= 1e12) {
      return '\$${(marketCap! / 1e12).toStringAsFixed(2)}T';
    } else if (marketCap! >= 1e9) {
      return '\$${(marketCap! / 1e9).toStringAsFixed(2)}B';
    } else if (marketCap! >= 1e6) {
      return '\$${(marketCap! / 1e6).toStringAsFixed(2)}M';
    } else {
      return '\$${marketCap!.toStringAsFixed(0)}';
    }
  }

  /// Get formatted volume string
  String get formattedVolume {
    if (volume == null) return 'N/A';

    if (volume! >= 1e9) {
      return '${(volume! / 1e9).toStringAsFixed(2)}B';
    } else if (volume! >= 1e6) {
      return '${(volume! / 1e6).toStringAsFixed(2)}M';
    } else if (volume! >= 1e3) {
      return '${(volume! / 1e3).toStringAsFixed(2)}K';
    } else {
      return volume!.toString();
    }
  }

  /// Get formatted day range string
  String get formattedDayRange {
    if (dayLow == null || dayHigh == null) return 'N/A';
    return '\$${dayLow!.toStringAsFixed(2)} - \$${dayHigh!.toStringAsFixed(2)}';
  }

  /// Get formatted year range string
  String get formattedYearRange {
    if (yearLow == null || yearHigh == null) return 'N/A';
    return '\$${yearLow!.toStringAsFixed(2)} - \$${yearHigh!.toStringAsFixed(2)}';
  }

  /// Get formatted 50-day average price
  String get formattedPriceAvg50 {
    if (priceAvg50 == null) return 'N/A';
    return '\$${priceAvg50!.toStringAsFixed(2)}';
  }

  /// Get formatted 200-day average price
  String get formattedPriceAvg200 {
    if (priceAvg200 == null) return 'N/A';
    return '\$${priceAvg200!.toStringAsFixed(2)}';
  }

  /// Check if stock is above 50-day average
  bool get isAbove50DayAvg {
    if (priceAvg50 == null) return false;
    return price > priceAvg50!;
  }

  /// Check if stock is above 200-day average
  bool get isAbove200DayAvg {
    if (priceAvg200 == null) return false;
    return price > priceAvg200!;
  }

  /// Create a copy of this Stock with updated values
  Stock copyWith({
    String? symbol,
    String? name,
    double? price,
    double? change,
    double? changePercent,
    String? currency,
    int? volume,
    double? marketCap,
    double? dayHigh,
    double? dayLow,
    double? yearHigh,
    double? yearLow,
    double? priceAvg50,
    double? priceAvg200,
    String? exchange,
    double? open,
    double? previousClose,
    DateTime? lastUpdated,
    int? timestamp,
  }) {
    return Stock(
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      price: price ?? this.price,
      change: change ?? this.change,
      changePercent: changePercent ?? this.changePercent,
      currency: currency ?? this.currency,
      volume: volume ?? this.volume,
      marketCap: marketCap ?? this.marketCap,
      dayHigh: dayHigh ?? this.dayHigh,
      dayLow: dayLow ?? this.dayLow,
      yearHigh: yearHigh ?? this.yearHigh,
      yearLow: yearLow ?? this.yearLow,
      priceAvg50: priceAvg50 ?? this.priceAvg50,
      priceAvg200: priceAvg200 ?? this.priceAvg200,
      exchange: exchange ?? this.exchange,
      open: open ?? this.open,
      previousClose: previousClose ?? this.previousClose,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'Stock(symbol: $symbol, name: $name, price: $price, change: $change)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Stock && other.symbol == symbol;
  }

  @override
  int get hashCode => symbol.hashCode;
}
