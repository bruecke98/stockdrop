import 'package:flutter_test/flutter_test.dart';
import 'package:stockdrop/models/gold.dart';

void main() {
  group('Gold Model Tests', () {
    test('Gold.fromQuoteJson creates valid object', () {
      final json = {
        'symbol': 'GCUSD',
        'name': 'Gold Commodity',
        'price': 2025.50,
        'change': 15.25,
        'changesPercentage': 0.76,
        'dayHigh': 2030.00,
        'dayLow': 2010.00,
        'open': 2010.25,
        'previousClose': 2010.25,
      };

      final gold = Gold.fromQuoteJson(json);

      expect(gold.symbol, equals('GCUSD'));
      expect(gold.name, equals('Gold Commodity'));
      expect(gold.price, equals(2025.50));
      expect(gold.change, equals(15.25));
      expect(gold.changePercent, equals(0.76));
      expect(gold.dayHigh, equals(2030.00));
      expect(gold.dayLow, equals(2010.00));
      expect(gold.open, equals(2010.25));
      expect(gold.previousClose, equals(2010.25));
    });

    test('Gold.fromHistoricalJson creates valid object', () {
      final json = {
        'date': '2024-01-15',
        'open': 2000.00,
        'high': 2025.50,
        'low': 1995.00,
        'close': 2020.00,
      };

      final gold = Gold.fromHistoricalJson(json);

      expect(gold.symbol, equals('GCUSD'));
      expect(gold.name, equals('Gold Commodity'));
      expect(gold.price, equals(2020.00));
      expect(gold.change, equals(20.00)); // close - open
      expect(gold.changePercent, equals(1.0)); // (change / open) * 100
      expect(gold.dayHigh, equals(2025.50));
      expect(gold.dayLow, equals(1995.00));
      expect(gold.open, equals(2000.00));
    });

    test('Gold formatting methods work correctly', () {
      final gold = Gold(
        symbol: 'GCUSD',
        name: 'Gold Commodity',
        price: 2025.50,
        change: 15.25,
        changePercent: 0.76,
      );

      expect(gold.formattedPrice, equals('\$2025.50'));
      expect(gold.formattedChange, equals('+\$15.25'));
      expect(gold.formattedChangePercent, equals('+0.76%'));
      expect(gold.isTrendingUp, isTrue);
      expect(gold.isTrendingDown, isFalse);
    });

    test('Gold trend detection works correctly', () {
      final goldUp = Gold(
        symbol: 'GCUSD',
        name: 'Gold Commodity',
        price: 2025.50,
        change: 15.25,
        changePercent: 0.76,
      );

      final goldDown = Gold(
        symbol: 'GCUSD',
        name: 'Gold Commodity',
        price: 2000.00,
        change: -10.50,
        changePercent: -0.52,
      );

      final goldFlat = Gold(
        symbol: 'GCUSD',
        name: 'Gold Commodity',
        price: 2020.00,
        change: 0.00,
        changePercent: 0.00,
      );

      expect(goldUp.isTrendingUp, isTrue);
      expect(goldUp.isTrendingDown, isFalse);
      expect(goldUp.isFlat, isFalse);

      expect(goldDown.isTrendingUp, isFalse);
      expect(goldDown.isTrendingDown, isTrue);
      expect(goldDown.isFlat, isFalse);

      expect(goldFlat.isTrendingUp, isFalse);
      expect(goldFlat.isTrendingDown, isFalse);
      expect(goldFlat.isFlat, isTrue);
    });

    test('Gold copyWith method works correctly', () {
      final original = Gold(
        symbol: 'GCUSD',
        name: 'Gold Commodity',
        price: 2025.50,
        change: 15.25,
        changePercent: 0.76,
      );

      final updated = original.copyWith(price: 2030.00, change: 20.25);

      expect(updated.symbol, equals(original.symbol));
      expect(updated.name, equals(original.name));
      expect(updated.price, equals(2030.00));
      expect(updated.change, equals(20.25));
      expect(updated.changePercent, equals(original.changePercent));
    });
  });

  group('GoldHistoricalPoint Tests', () {
    test('GoldHistoricalPoint.fromJson creates valid object', () {
      final json = {
        'date': '2024-01-15T00:00:00.000Z',
        'open': 2000.00,
        'high': 2025.50,
        'low': 1995.00,
        'close': 2020.00,
      };

      final point = GoldHistoricalPoint.fromJson(json);

      expect(point.date, equals(DateTime.parse('2024-01-15T00:00:00.000Z')));
      expect(point.price, equals(2020.00));
      expect(point.high, equals(2025.50));
      expect(point.low, equals(1995.00));
      expect(point.open, equals(2000.00));
    });

    test('GoldHistoricalPoint toJson creates valid JSON', () {
      final point = GoldHistoricalPoint(
        date: DateTime.parse('2024-01-15T00:00:00.000Z'),
        price: 2020.00,
        high: 2025.50,
        low: 1995.00,
        open: 2000.00,
      );

      final json = point.toJson();

      expect(json['date'], equals('2024-01-15T00:00:00.000Z'));
      expect(json['price'], equals(2020.00));
      expect(json['high'], equals(2025.50));
      expect(json['low'], equals(1995.00));
      expect(json['open'], equals(2000.00));
    });
  });
}
