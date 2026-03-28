import 'package:dio/dio.dart';

/// Fetches historical price data from Yahoo Finance.
/// No API key required. Used until Firebase Functions are deployed.
class MarketDataService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://query1.finance.yahoo.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'User-Agent': 'Mozilla/5.0'},
  ));

  /// Maps app symbol + type to a Yahoo Finance ticker.
  static String toYahooTicker(String symbol, String type) {
    return switch (type) {
      'crypto' => '${symbol.toUpperCase()}-USD',
      'gold' => 'GC=F',
      'silver' => 'SI=F',
      _ => symbol.toUpperCase(),
    };
  }

  static ({String range, String interval}) _yahooParams(String range) {
    return switch (range) {
      '1D'  => (range: '1d',   interval: '5m'),
      '1W'  => (range: '5d',   interval: '1h'),
      '1M'  => (range: '1mo',  interval: '1d'),
      '3M'  => (range: '3mo',  interval: '1d'),
      '1Y'  => (range: '1y',   interval: '1wk'),
      '5Y'  => (range: '5y',   interval: '1mo'),
      '10Y' => (range: '10y',  interval: '1mo'),
      'All' => (range: 'max',  interval: '1mo'),
      _     => (range: '1mo',  interval: '1d'),
    };
  }

  /// Fetches OHLC close prices for [symbol]/[type] over [range].
  Future<List<({DateTime time, double price})>> fetchHistory(
    String symbol,
    String type,
    String range,
  ) async {
    final ticker = toYahooTicker(symbol, type);
    final params = _yahooParams(range);

    final response = await _dio.get(
      '/v8/finance/chart/$ticker',
      queryParameters: {
        'interval': params.interval,
        'range': params.range,
      },
    );

    final result =
        (response.data['chart']['result'] as List?)?.firstOrNull;
    if (result == null) return [];

    final timestamps = (result['timestamp'] as List?)?.cast<int>() ?? [];
    final closes =
        ((result['indicators']['quote'] as List).firstOrNull?['close']
                as List?) ??
            [];

    final points = <({DateTime time, double price})>[];
    for (var i = 0; i < timestamps.length; i++) {
      final raw = i < closes.length ? closes[i] : null;
      if (raw == null) continue;
      points.add((
        time: DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000),
        price: (raw as num).toDouble(),
      ));
    }
    return points;
  }
}
