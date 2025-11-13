/// Model class for market hours data from FMP API
class MarketHours {
  final String exchange;
  final String name;
  final String openingHour;
  final String closingHour;
  final String timezone;
  final bool isMarketOpen;

  MarketHours({
    required this.exchange,
    required this.name,
    required this.openingHour,
    required this.closingHour,
    required this.timezone,
    required this.isMarketOpen,
  });

  factory MarketHours.fromJson(Map<String, dynamic> json) {
    return MarketHours(
      exchange: json['exchange']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      openingHour: json['openingHour']?.toString() ?? '',
      closingHour: json['closingHour']?.toString() ?? '',
      timezone: json['timezone']?.toString() ?? '',
      isMarketOpen: json['isMarketOpen'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exchange': exchange,
      'name': name,
      'openingHour': openingHour,
      'closingHour': closingHour,
      'timezone': timezone,
      'isMarketOpen': isMarketOpen,
    };
  }
}
