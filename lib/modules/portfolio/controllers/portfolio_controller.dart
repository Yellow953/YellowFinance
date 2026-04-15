import 'dart:async';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/models/asset_model.dart';
import '../../../data/repositories/portfolio_repository.dart';
import '../../auth/controllers/auth_controller.dart';

/// Manages the watchlist assets with live price enrichment.
class PortfolioController extends GetxController {
  final PortfolioRepository _portfolioRepo;

  final RxList<AssetModel> assets = <AssetModel>[].obs;
  final RxString selectedFilter = 'All'.obs;
  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;

  StreamSubscription<List<AssetModel>>? _sub;

  // In-memory price cache: symbol → (price, change24h, fetchedAt)
  final Map<String, ({double? price, double? change24h, DateTime fetchedAt})>
      _priceCache = {};
  static const _priceCacheTtl = Duration(minutes: 5);

  static const List<String> filterOptions = [
    'All',
    'Stocks',
    'Crypto',
    'Gold',
  ];

  /// Default watchlist seeded for every new user.
  static const _defaultAssets = [
    (symbol: 'BTC', type: 'crypto'),
    (symbol: 'ETH', type: 'crypto'),
    (symbol: 'GOLD', type: 'gold'),
    (symbol: 'SILVER', type: 'silver'),
    (symbol: 'VOO', type: 'etf'),
    (symbol: 'VTI', type: 'etf'),
    (symbol: 'AAPL', type: 'stock'),
    (symbol: 'AMZN', type: 'stock'),
    (symbol: 'GOOGL', type: 'stock'),
    (symbol: 'QYLD', type: 'etf'),
    (symbol: 'PLTR', type: 'stock'),
    (symbol: 'TSLA', type: 'stock'),
    (symbol: 'T', type: 'stock'),
    (symbol: 'KO', type: 'stock'),
  ];

  PortfolioController({required PortfolioRepository portfolioRepo})
      : _portfolioRepo = portfolioRepo;

  @override
  void onInit() {
    super.onInit();
    _subscribe();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void _subscribe() {
    final uid = Get.find<AuthController>().user.value?.uid;
    if (uid == null) return;
    isLoading.value = true;
    bool seeded = false;
    _sub = _portfolioRepo.watchPortfolio(uid).listen(
      (list) async {
        if (list.isEmpty && !seeded) {
          seeded = true;
          try {
            await _seedDefaults(uid);
          } catch (_) {
            AppSnackbar.error('Could not initialise watchlist.');
          }
          return; // next snapshot will carry the seeded items
        }
        final enriched = await _enrichWithMarketData(list);
        assets.assignAll(enriched);
        isLoading.value = false;
      },
      onError: (_) => isLoading.value = false,
    );
  }

  Future<void> _seedDefaults(String uid) async {
    final now = DateTime.now();
    await Future.wait([
      for (var i = 0; i < _defaultAssets.length; i++)
        _portfolioRepo.addAsset(
          uid: uid,
          symbol: _defaultAssets[i].symbol,
          type: _defaultAssets[i].type,
          // Spread createdAt by 1ms so ordering is stable
          createdAt: now.add(Duration(milliseconds: i)),
        ),
    ]);
  }

  Future<List<AssetModel>> _enrichWithMarketData(
      List<AssetModel> list, {bool forceRefresh = false}) async {
    final now = DateTime.now();
    final results = await Future.wait(
      list.map((asset) async {
        final cached = _priceCache[asset.symbol];
        if (!forceRefresh &&
            cached != null &&
            now.difference(cached.fetchedAt) < _priceCacheTtl) {
          return (price: cached.price, change24h: cached.change24h);
        }
        final fresh = await _portfolioRepo.fetchMarketData(asset.symbol);
        _priceCache[asset.symbol] = (
          price: fresh.price,
          change24h: fresh.change24h,
          fetchedAt: now,
        );
        return fresh;
      }),
    );
    return [
      for (var i = 0; i < list.length; i++)
        list[i].withMarketData(
          price: results[i].price,
          change24h: results[i].change24h,
        ),
    ];
  }

  /// Forces a fresh price fetch and rebuilds the asset list.
  Future<void> refreshPrices() async {
    if (assets.isEmpty) return;
    isRefreshing.value = true;
    try {
      final stripped = assets
          .map((a) => a.withMarketData(price: null, change24h: null))
          .toList();
      final refreshed = await _enrichWithMarketData(
        stripped,
        forceRefresh: true,
      );
      assets.assignAll(refreshed);
    } finally {
      isRefreshing.value = false;
    }
  }

  List<AssetModel> get filteredAssets {
    if (selectedFilter.value == 'All') return assets;
    final typeMap = {
      'Stocks': [AppConstants.assetStock, AppConstants.assetEtf],
      'Crypto': [AppConstants.assetCrypto],
      'Gold': [AppConstants.assetGold, AppConstants.assetSilver],
    };
    final types = typeMap[selectedFilter.value] ?? [];
    return assets.where((a) => types.contains(a.type)).toList();
  }

  /// Removes an asset from the watchlist.
  Future<void> removeAsset(String assetId) async {
    final uid = Get.find<AuthController>().user.value?.uid;
    if (uid == null) return;
    try {
      await _portfolioRepo.removeAsset(uid, assetId);
    } catch (_) {
      AppSnackbar.error('Could not remove asset.');
    }
  }
}
