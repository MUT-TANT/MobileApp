import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class PriceService {
  static final PriceService _instance = PriceService._internal();
  factory PriceService() => _instance;

  PriceService._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.coingecko.com/api/v3',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // Cache settings
  double? _cachedDaiUsdRate;
  DateTime? _lastFetchTime;
  static const _cacheDuration = Duration(minutes: 5);

  /// Get DAI to USD exchange rate (cached for 5 minutes)
  Future<double> getDaiUsdRate() async {
    // Return cached rate if valid
    if (_cachedDaiUsdRate != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return _cachedDaiUsdRate!;
    }

    try {
      final response = await _dio.get('/simple/price', queryParameters: {
        'ids': 'dai',
        'vs_currencies': 'usd',
      });

      final rate = response.data['dai']['usd'] as num;
      _cachedDaiUsdRate = rate.toDouble();
      _lastFetchTime = DateTime.now();

      if (kDebugMode) {
        print('💱 DAI/USD Rate: $_cachedDaiUsdRate');
      }

      return _cachedDaiUsdRate!;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching DAI price: $e');
      }
      // Fallback: Return 1.0 (DAI is a stablecoin)
      return 1.0;
    }
  }

  /// Convert USD amount to DAI amount
  Future<double> convertUsdToDai(double usdAmount) async {
    final rate = await getDaiUsdRate();
    return usdAmount / rate; // If DAI = $1.00, then $5 USD = 5 DAI
  }

  /// Format DAI amount for display
  String formatDaiAmount(double daiAmount) {
    return daiAmount.toStringAsFixed(2);
  }

  /// Clear cache (useful for manual refresh)
  void clearCache() {
    _cachedDaiUsdRate = null;
    _lastFetchTime = null;
  }
}
