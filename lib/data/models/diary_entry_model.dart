import 'package:cloud_firestore/cloud_firestore.dart';

/// How the user felt when writing an entry. Stored as the enum name.
enum Mood { none, great, good, okay, low, bad }

/// A single diary / memo entry.
///
/// [date] is the day the entry is *about* (the user can back-date), while
/// [createdAt] is when it was written — the list groups by the former and
/// breaks ties with the latter.
class DiaryEntryModel {
  final String id;
  final String title;
  final String body;
  final Mood mood;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// True if any part of this entry was dictated rather than typed. Purely
  /// informational — it drives the small mic marker in the list.
  final bool hasVoice;

  /// True while this entry has a local write not yet acknowledged by the
  /// server. Client-derived state — never written to the document.
  final bool pendingSync;

  const DiaryEntryModel({
    required this.id,
    required this.title,
    required this.body,
    required this.mood,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.hasVoice = false,
    this.pendingSync = false,
  });

  /// First line of the body, for the collapsed list row.
  String get preview {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '';
    final firstBreak = trimmed.indexOf('\n');
    return firstBreak == -1 ? trimmed : trimmed.substring(0, firstBreak);
  }

  /// Rough word count, shown on the entry row.
  int get wordCount =>
      body.trim().isEmpty ? 0 : body.trim().split(RegExp(r'\s+')).length;

  factory DiaryEntryModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final created =
        (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return DiaryEntryModel(
      id: doc.id,
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      mood: _parseMood(d['mood'] as String?),
      date: (d['date'] as Timestamp?)?.toDate() ?? created,
      createdAt: created,
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? created,
      hasVoice: d['hasVoice'] as bool? ?? false,
      pendingSync: doc.metadata.hasPendingWrites,
    );
  }

  static Mood _parseMood(String? value) => Mood.values.firstWhere(
        (m) => m.name == value,
        orElse: () => Mood.none,
      );

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'body': body,
        'mood': mood.name,
        'date': Timestamp.fromDate(date),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'hasVoice': hasVoice,
      };

  DiaryEntryModel copyWith({
    String? title,
    String? body,
    Mood? mood,
    DateTime? date,
    DateTime? updatedAt,
    bool? hasVoice,
    bool? pendingSync,
  }) =>
      DiaryEntryModel(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        mood: mood ?? this.mood,
        date: date ?? this.date,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        hasVoice: hasVoice ?? this.hasVoice,
        pendingSync: pendingSync ?? this.pendingSync,
      );
}

/// Display metadata for each mood, kept beside the enum so the list and the
/// editor can never disagree about what a mood looks like.
extension MoodDisplay on Mood {
  String get emoji => switch (this) {
        Mood.none => '',
        Mood.great => '😄',
        Mood.good => '🙂',
        Mood.okay => '😐',
        Mood.low => '😕',
        Mood.bad => '😣',
      };

  String get label => switch (this) {
        Mood.none => 'No mood',
        Mood.great => 'Great',
        Mood.good => 'Good',
        Mood.okay => 'Okay',
        Mood.low => 'Low',
        Mood.bad => 'Bad',
      };
}
