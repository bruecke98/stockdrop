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
  final double? open;
  final double? previousClose;
  final DateTime? lastUpdated;

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
    this.open,
    this.previousClose,
    this.lastUpdated,
  });

  /// Create Stock from JSON (typically from API response)
  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      symbol: json['symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: _parseDouble(json['price']) ?? 0.0,
      change: _parseDouble(json['change']) ?? 0.0,
      changePercent: _parseDouble(json['changePercent']) ?? 0.0,
      currency: json['currency']?.toString(),
      volume: _parseInt(json['volume']),
      marketCap: _parseDouble(json['marketCap']),
      dayHigh: _parseDouble(json['dayHigh']),
      dayLow: _parseDouble(json['dayLow']),
      open: _parseDouble(json['open']),
      previousClose: _parseDouble(json['previousClose']),
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'].toString())
          : null,
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
      'open': open,
      'previousClose': previousClose,
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
    double? open,
    double? previousClose,
    DateTime? lastUpdated,
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
      open: open ?? this.open,
      previousClose: previousClose ?? this.previousClose,
      lastUpdated: lastUpdated ?? this.lastUpdated,
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
