import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import '../../../core/services/market_data_service.dart';
import '../../../data/models/asset_model.dart';

/// Manages price history data for the asset detail chart.
class AssetDetailController extends GetxController {
  final MarketDataService _marketData;
  final AssetModel asset;

  final RxString selectedRange = '1W'.obs;
  final RxList<FlSpot> spots = <FlSpot>[].obs;
  final RxBool isLoadingChart = false.obs;
  final Rx<double?> touchedPrice = Rx<double?>(null);
  final RxDouble chartHigh = 0.0.obs;
  final RxDouble chartLow = 0.0.obs;

  // Cache fetched data per range so switching back doesn't re-fetch.
  final Map<String, List<FlSpot>> _cache = {};
  final Map<String, ({double high, double low})> _statsCache = {};

  static const List<String> ranges = ['1D', '1W', '1M', '3M', '1Y', '5Y', '10Y', 'All'];

  AssetDetailController({
    required MarketDataService marketData,
    required this.asset,
  }) : _marketData = marketData;

  @override
  void onInit() {
    super.onInit();
    ever(selectedRange, (_) => _loadHistory());
    _loadHistory();
  }

  bool get chartIsPositive {
    if (spots.length < 2) return true;
    return spots.last.y >= spots.first.y;
  }

  Future<void> _loadHistory() async {
    final range = selectedRange.value;
    touchedPrice.value = null;

    // Serve from cache instantly if available.
    if (_cache.containsKey(range)) {
      spots.assignAll(_cache[range]!);
      final stats = _statsCache[range]!;
      chartHigh.value = stats.high;
      chartLow.value = stats.low;
      return;
    }

    isLoadingChart.value = true;
    try {
      final history = await _marketData.fetchHistory(
        asset.symbol,
        asset.type,
        range,
      );
      if (history.isEmpty) {
        spots.clear();
        _cache[range] = [];
      } else {
        final newSpots = history.asMap().entries
            .map((e) => FlSpot(e.key.toDouble(), e.value.price))
            .toList();
        final prices = history.map((h) => h.price).toList();
        final high = prices.reduce(max);
        final low = prices.reduce(min);
        _cache[range] = newSpots;
        _statsCache[range] = (high: high, low: low);
        spots.assignAll(newSpots);
        chartHigh.value = high;
        chartLow.value = low;
      }
    } catch (_) {
      spots.clear();
    } finally {
      isLoadingChart.value = false;
    }
  }
}
