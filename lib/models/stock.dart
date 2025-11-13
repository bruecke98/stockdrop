import 'package:flutter/material.dart';

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
  final double? beta;
  final String? sector;
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
  final String? country;

  Stock({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change,
    required this.changePercent,
    this.currency,
    this.volume,
    this.marketCap,
    this.beta,
    this.sector,
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
    this.country,
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
      beta: _parseDouble(json['beta']),
      sector: json['sector']?.toString(),
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
      country: json['country']?.toString(),
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
      'beta': beta,
      'sector': sector,
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

  /// Get formatted beta string
  String get formattedBeta {
    if (beta == null) return 'N/A';
    return beta!.toStringAsFixed(2);
  }

  /// Get market cap category
  String get marketCapCategory {
    if (marketCap == null) return 'N/A';

    if (marketCap! >= 200e9) {
      // $200B+
      return 'Mega Cap';
    } else if (marketCap! >= 10e9) {
      // $10B-$200B
      return 'Large Cap';
    } else if (marketCap! >= 2e9) {
      // $2B-$10B
      return 'Mid Cap';
    } else if (marketCap! >= 300e6) {
      // $300M-$2B
      return 'Small Cap';
    } else if (marketCap! >= 50e6) {
      // $50M-$300M
      return 'Micro Cap';
    } else {
      // <$50M
      return 'Nano Cap';
    }
  }

  /// Get beta color for UI display
  Color getBetaColor(BuildContext context) {
    if (beta == null) return Theme.of(context).colorScheme.onSurfaceVariant;

    if (beta! > 3.0) {
      return Colors.red;
    } else if (beta! > 1.0) {
      return Colors.yellow.shade700;
    } else if (beta! == 1.0) {
      return Colors.green;
    } else {
      return Colors.blue;
    }
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
    double? beta,
    String? sector,
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
      beta: beta ?? this.beta,
      sector: sector ?? this.sector,
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

/// Company Profile model for detailed company information
class CompanyProfile {
  final String symbol;
  final double? price;
  final double? marketCap;
  final double? beta;
  final double? lastDividend;
  final String? range;
  final double? change;
  final double? changePercentage;
  final int? volume;
  final int? averageVolume;
  final String? companyName;
  final String? currency;
  final String? cik;
  final String? isin;
  final String? cusip;
  final String? exchangeFullName;
  final String? exchange;
  final String? industry;
  final String? website;
  final String? description;
  final String? ceo;
  final String? sector;
  final String? country;
  final String? fullTimeEmployees;
  final String? phone;
  final String? address;
  final String? city;
  final String? state;
  final String? zip;
  final String? image;
  final String? ipoDate;
  final bool? defaultImage;
  final bool? isEtf;
  final bool? isActivelyTrading;
  final bool? isAdr;
  final bool? isFund;

  CompanyProfile({
    required this.symbol,
    this.price,
    this.marketCap,
    this.beta,
    this.lastDividend,
    this.range,
    this.change,
    this.changePercentage,
    this.volume,
    this.averageVolume,
    this.companyName,
    this.currency,
    this.cik,
    this.isin,
    this.cusip,
    this.exchangeFullName,
    this.exchange,
    this.industry,
    this.website,
    this.description,
    this.ceo,
    this.sector,
    this.country,
    this.fullTimeEmployees,
    this.phone,
    this.address,
    this.city,
    this.state,
    this.zip,
    this.image,
    this.ipoDate,
    this.defaultImage,
    this.isEtf,
    this.isActivelyTrading,
    this.isAdr,
    this.isFund,
  });

  /// Create CompanyProfile from JSON
  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    return CompanyProfile(
      symbol: json['symbol']?.toString() ?? '',
      price: _parseDouble(json['price']),
      marketCap: _parseDouble(json['marketCap']),
      beta: _parseDouble(json['beta']),
      lastDividend: _parseDouble(json['lastDividend']),
      range: json['range']?.toString(),
      change: _parseDouble(json['change']),
      changePercentage: _parseDouble(json['changePercentage']),
      volume: _parseInt(json['volume']),
      averageVolume: _parseInt(json['averageVolume']),
      companyName: json['companyName']?.toString(),
      currency: json['currency']?.toString(),
      cik: json['cik']?.toString(),
      isin: json['isin']?.toString(),
      cusip: json['cusip']?.toString(),
      exchangeFullName: json['exchangeFullName']?.toString(),
      exchange: json['exchange']?.toString(),
      industry: json['industry']?.toString(),
      website: json['website']?.toString(),
      description: json['description']?.toString(),
      ceo: json['ceo']?.toString(),
      sector: json['sector']?.toString(),
      country: json['country']?.toString(),
      fullTimeEmployees: json['fullTimeEmployees']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      zip: json['zip']?.toString(),
      image: json['image']?.toString(),
      ipoDate: json['ipoDate']?.toString(),
      defaultImage: json['defaultImage'] as bool?,
      isEtf: json['isEtf'] as bool?,
      isActivelyTrading: json['isActivelyTrading'] as bool?,
      isAdr: json['isAdr'] as bool?,
      isFund: json['isFund'] as bool?,
    );
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

  /// Get formatted market cap
  String get formattedMarketCap {
    if (marketCap == null) return 'N/A';
    if (marketCap! >= 1000000000000) {
      return '\$${(marketCap! / 1000000000000).toStringAsFixed(2)}T';
    } else if (marketCap! >= 1000000000) {
      return '\$${(marketCap! / 1000000000).toStringAsFixed(2)}B';
    } else if (marketCap! >= 1000000) {
      return '\$${(marketCap! / 1000000).toStringAsFixed(2)}M';
    }
    return '\$${marketCap!.toStringAsFixed(0)}';
  }

  /// Get formatted price
  String get formattedPrice {
    if (price == null) return 'N/A';
    return '\$${price!.toStringAsFixed(2)}';
  }

  /// Get formatted beta
  String get formattedBeta {
    if (beta == null) return 'N/A';
    return beta!.toStringAsFixed(2);
  }

  /// Get formatted last dividend
  String get formattedLastDividend {
    if (lastDividend == null) return 'N/A';
    return '\$${lastDividend!.toStringAsFixed(2)}';
  }

  /// Get formatted volume
  String get formattedVolume {
    if (volume == null) return 'N/A';
    if (volume! >= 1000000) {
      return '${(volume! / 1000000).toStringAsFixed(1)}M';
    } else if (volume! >= 1000) {
      return '${(volume! / 1000).toStringAsFixed(1)}K';
    }
    return volume!.toString();
  }

  /// Get formatted employees
  String get formattedEmployees {
    if (fullTimeEmployees == null) return 'N/A';
    final count = int.tryParse(fullTimeEmployees!);
    if (count == null) return fullTimeEmployees!;
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  String toString() {
    return 'CompanyProfile(symbol: $symbol, companyName: $companyName, sector: $sector, industry: $industry)';
  }
}
