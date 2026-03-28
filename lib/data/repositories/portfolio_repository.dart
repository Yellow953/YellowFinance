import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/asset_model.dart';
import '../providers/firestore_provider.dart';

/// CRUD operations for portfolio assets.
class PortfolioRepository {
  final FirestoreProvider _firestore;
  final _uuid = const Uuid();

  PortfolioRepository({required FirestoreProvider firestore})
      : _firestore = firestore;

  /// Streams all assets for [uid] with live market prices merged in.
  Stream<List<AssetModel>> watchPortfolio(String uid) {
    return _firestore
        .portfolioCollection(uid)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(AssetModel.fromFirestore).toList());
  }

  /// Fetches assets once (no real-time).
  Future<List<AssetModel>> fetchPortfolio(String uid) async {
    final snap = await _firestore.portfolioCollection(uid).get();
    return snap.docs.map(AssetModel.fromFirestore).toList();
  }

  /// Fetches the current price and 24h change for a symbol from market_prices.
  Future<({double? price, double? change24h})> fetchMarketData(
      String symbol) async {
    final doc = await _firestore.marketPriceDoc(symbol.toUpperCase()).get();
    if (!doc.exists) return (price: null, change24h: null);
    final data = doc.data()!;
    return (
      price: (data['price'] as num?)?.toDouble(),
      change24h: (data['change24h'] as num?)?.toDouble(),
    );
  }

  /// Adds a new watchlist asset (symbol + type only — no quantity or price).
  Future<AssetModel> addAsset({
    required String uid,
    required String symbol,
    required String type,
    DateTime? createdAt,
  }) async {
    final id = _uuid.v4();
    final asset = AssetModel(
      id: id,
      symbol: symbol.toUpperCase(),
      type: type,
      createdAt: createdAt ?? DateTime.now(),
    );
    await _firestore
        .portfolioCollection(uid)
        .doc(id)
        .set(asset.toFirestore());
    return asset;
  }

  /// Fetches historical prices for [symbol] over [range] (1D/1W/1M/3M/1Y).
  /// Reads from `market_prices/{symbol}/history` — written by the fetch Function.
  Future<List<({DateTime time, double price})>> fetchPriceHistory(
      String symbol, String range) async {
    final now = DateTime.now();
    final cutoff = switch (range) {
      '1D' => now.subtract(const Duration(hours: 24)),
      '1W' => now.subtract(const Duration(days: 7)),
      '1M' => now.subtract(const Duration(days: 30)),
      '3M' => now.subtract(const Duration(days: 90)),
      '1Y' => now.subtract(const Duration(days: 365)),
      _ => now.subtract(const Duration(days: 7)),
    };
    final snap = await _firestore
        .priceHistoryCollection(symbol.toUpperCase())
        .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('timestamp')
        .get();
    return snap.docs.map((doc) {
      final d = doc.data();
      return (
        time: (d['timestamp'] as Timestamp).toDate(),
        price: (d['price'] as num).toDouble(),
      );
    }).toList();
  }

  /// Removes an asset from the portfolio.
  Future<void> removeAsset(String uid, String assetId) async {
    await _firestore.portfolioCollection(uid).doc(assetId).delete();
  }
}
