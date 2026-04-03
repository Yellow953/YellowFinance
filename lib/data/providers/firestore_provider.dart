import 'package:cloud_firestore/cloud_firestore.dart';

/// Provides typed Firestore collection references.
class FirestoreProvider {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> usersCollection() =>
      _db.collection('users');

  DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> transactionsCollection(String uid) =>
      _db.collection('users').doc(uid).collection('transactions');

  CollectionReference<Map<String, dynamic>> portfolioCollection(String uid) =>
      _db.collection('users').doc(uid).collection('portfolio');

  CollectionReference<Map<String, dynamic>> marketPricesCollection() =>
      _db.collection('market_prices');

  DocumentReference<Map<String, dynamic>> marketPriceDoc(String symbol) =>
      _db.collection('market_prices').doc(symbol);

  CollectionReference<Map<String, dynamic>> priceHistoryCollection(
          String symbol) =>
      _db.collection('market_prices').doc(symbol).collection('history');
}