/// Gold commodity model class for StockDrop app
/// Represents gold price data with current price and market information
class Gold {
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

  Gold({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change,
    required this.changePercent,
    this.currency = 'USD',
    this.dayHigh,
    this.dayLow,
    this.open,
    this.previousClose,
    this.lastUpdated,
  });

  /// Create Gold from JSON (from FMP API quote endpoint)
  factory Gold.fromQuoteJson(Map<String, dynamic> json) {
    final price = _parseDouble(json['price']) ?? 0.0;
    final change = _parseDouble(json['change']) ?? 0.0;
    final changePercent = _parseDouble(json['changesPercentage']) ?? 0.0;

    return Gold(
      symbol: json['symbol']?.toString() ?? 'GCUSD',
      name: json['name']?.toString() ?? 'Gold Commodity',
      price: price,
      change: change,
      changePercent: changePercent,
      currency: 'USD',
      dayHigh: _parseDouble(json['dayHigh']),
      dayLow: _parseDouble(json['dayLow']),
      open: _parseDouble(json['open']),
      previousClose: _parseDouble(json['previousClose']),
      lastUpdated: DateTime.now(),
    );
  }

  /// Create Gold from historical price JSON (from FMP API historical endpoint)
  factory Gold.fromHistoricalJson(Map<String, dynamic> json) {
    final close = _parseDouble(json['close']) ?? 0.0;
    final open = _parseDouble(json['open']) ?? 0.0;
    final change = close - open;
    final changePercent = open != 0 ? (change / open) * 100 : 0.0;

    return Gold(
      symbol: 'GCUSD',
      name: 'Gold Commodity',
      price: close,
      change: change,
      changePercent: changePercent,
      currency: 'USD',
      dayHigh: _parseDouble(json['high']),
      dayLow: _parseDouble(json['low']),
      open: open,
      previousClose: open,
      lastUpdated: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())
          : DateTime.now(),
    );
  }

  /// Convert Gold to JSON
  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'name': name,
      'price': price,
      'change': change,
      'changePercent': changePercent,
      'currency': currency,
      'dayHigh': dayHigh,
      'dayLow': dayLow,
      'open': open,
      'previousClose': previousClose,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  /// Copy with method for updating gold data
  Gold copyWith({
    String? symbol,
    String? name,
    double? price,
    double? change,
    double? changePercent,
    String? currency,
    double? dayHigh,
    double? dayLow,
    double? open,
    double? previousClose,
    DateTime? lastUpdated,
  }) {
    return Gold(
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      price: price ?? this.price,
      change: change ?? this.change,
      changePercent: changePercent ?? this.changePercent,
      currency: currency ?? this.currency,
      dayHigh: dayHigh ?? this.dayHigh,
      dayLow: dayLow ?? this.dayLow,
      open: open ?? this.open,
      previousClose: previousClose ?? this.previousClose,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() {
    return 'Gold(symbol: $symbol, price: \$${price.toStringAsFixed(2)}, change: ${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)} (${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%))';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Gold &&
        other.symbol == symbol &&
        other.name == name &&
        other.price == price &&
        other.change == change &&
        other.changePercent == changePercent;
  }

  @override
  int get hashCode {
    return symbol.hashCode ^
        name.hashCode ^
        price.hashCode ^
        change.hashCode ^
        changePercent.hashCode;
  }

  /// Format price as currency string
  String get formattedPrice => '\$${price.toStringAsFixed(2)}';

  /// Format change as currency string with sign
  String get formattedChange =>
      '${change >= 0 ? '+' : ''}\$${change.toStringAsFixed(2)}';

  /// Format change percentage with sign
  String get formattedChangePercent =>
      '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%';

  /// Check if gold price is trending up
  bool get isTrendingUp => changePercent > 0;

  /// Check if gold price is trending down
  bool get isTrendingDown => changePercent < 0;

  /// Check if gold price is flat
  bool get isFlat => changePercent == 0;
}

/// Helper function to safely parse double values
double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    return parsed;
  }
  return null;
}

/// Historical gold price data point for charts
class GoldHistoricalPoint {
  final DateTime date;
  final double price;
  final double? high;
  final double? low;
  final double? open;

  GoldHistoricalPoint({
    required this.date,
    required this.price,
    this.high,
    this.low,
    this.open,
  });

  factory GoldHistoricalPoint.fromJson(Map<String, dynamic> json) {
    return GoldHistoricalPoint(
      date: DateTime.parse(json['date']),
      price: _parseDouble(json['close']) ?? 0.0,
      high: _parseDouble(json['high']),
      low: _parseDouble(json['low']),
      open: _parseDouble(json['open']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'price': price,
      'high': high,
      'low': low,
      'open': open,
    };
  }
}
