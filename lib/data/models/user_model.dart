import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents a YellowFinance user document.
class UserModel extends Equatable {
  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;
  final String currency;
  final DateTime createdAt;
  final Map<String, dynamic> settings;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl = '',
    this.currency = 'USD',
    required this.createdAt,
    this.settings = const {},
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      photoUrl: data['photoUrl'] as String? ?? '',
      currency: data['currency'] as String? ?? 'USD',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      settings: data['settings'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toFirestore() => {
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
        'currency': currency,
        'createdAt': Timestamp.fromDate(createdAt),
        'settings': settings,
      };

  UserModel copyWith({
    String? displayName,
    String? photoUrl,
    String? currency,
    Map<String, dynamic>? settings,
  }) =>
      UserModel(
        uid: uid,
        displayName: displayName ?? this.displayName,
        email: email,
        photoUrl: photoUrl ?? this.photoUrl,
        currency: currency ?? this.currency,
        createdAt: createdAt,
        settings: settings ?? this.settings,
      );

  @override
  List<Object?> get props => [uid, displayName, email, photoUrl, currency];
}
