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

  CollectionReference<Map<String, dynamic>> budgetsCollection(String uid) =>
      _db.collection('users').doc(uid).collection('budgets');

  CollectionReference<Map<String, dynamic>> goalsCollection(String uid) =>
      _db.collection('users').doc(uid).collection('goals');

  CollectionReference<Map<String, dynamic>> diaryCollection(String uid) =>
      _db.collection('users').doc(uid).collection('diary');
}