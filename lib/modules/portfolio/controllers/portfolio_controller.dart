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

  StreamSubscription<List<AssetModel>>? _sub;

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
          await _seedDefaults(uid);
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
    for (var i = 0; i < _defaultAssets.length; i++) {
      final entry = _defaultAssets[i];
      await _portfolioRepo.addAsset(
        uid: uid,
        symbol: entry.symbol,
        type: entry.type,
        // Spread createdAt by 1ms so ordering is stable
        createdAt: now.add(Duration(milliseconds: i)),
      );
    }
  }

  Future<List<AssetModel>> _enrichWithMarketData(
      List<AssetModel> list) async {
    final results = await Future.wait(
      list.map((asset) => _portfolioRepo.fetchMarketData(asset.symbol)),
    );
    return [
      for (var i = 0; i < list.length; i++)
        list[i].withMarketData(
          price: results[i].price,
          change24h: results[i].change24h,
        ),
    ];
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
