import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// A watchlist item — symbol the user wants to research or track.
class AssetModel extends Equatable {
  final String id;
  final String symbol;
  final String type; // 'crypto' | 'stock' | 'etf' | 'gold' | 'silver'
  final DateTime createdAt;

  // Live data injected from market_prices collection (not stored in Firestore)
  final double? currentPrice;
  final double? priceChange24h; // percentage

  const AssetModel({
    required this.id,
    required this.symbol,
    required this.type,
    required this.createdAt,
    this.currentPrice,
    this.priceChange24h,
  });

  factory AssetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AssetModel(
      id: doc.id,
      symbol: data['symbol'] as String? ?? '',
      type: data['type'] as String? ?? 'stock',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'symbol': symbol,
        'type': type,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  AssetModel withMarketData({double? price, double? change24h}) => AssetModel(
        id: id,
        symbol: symbol,
        type: type,
        createdAt: createdAt,
        currentPrice: price,
        priceChange24h: change24h,
      );

  @override
  List<Object?> get props => [id, symbol, type];
}
