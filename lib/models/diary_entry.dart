/// DiaryEntry — a single diary / event entry.
///
// Time-stamp: <2026-04-26>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

/// A diary entry representing an attended or scheduled event.
class DiaryEntry {
  final String id;

  /// The date and time of the event (past = attended, future = scheduled).
  final DateTime eventDate;

  /// Short title / headline for the entry.
  final String title;

  /// Free-form Markdown notes.
  final String note;

  /// User-defined tags for filtering and autocomplete.
  final List<String> tags;

  /// Optional location string.
  final String? location;

  /// When this record was first created.
  final DateTime createdAt;

  /// When this record was last modified.
  final DateTime modifiedAt;

  const DiaryEntry({
    required this.id,
    required this.eventDate,
    required this.title,
    this.note = '',
    this.tags = const [],
    this.location,
    required this.createdAt,
    required this.modifiedAt,
  });

  /// Whether this entry is a future (scheduled) event.
  bool get isFuture => eventDate.isAfter(DateTime.now());

  /// True when the entry has meaningful notes.
  bool get hasNote => note.trim().isNotEmpty;

  // ── Serialisation ───────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventDate': eventDate.toIso8601String(),
    'title': title,
    'note': note,
    'tags': tags,
    if (location != null) 'location': location,
    'createdAt': createdAt.toIso8601String(),
    'modifiedAt': modifiedAt.toIso8601String(),
  };

  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
    id: j['id'] as String,
    eventDate: DateTime.parse(j['eventDate'] as String),
    title: j['title'] as String,
    note: (j['note'] as String?) ?? '',
    tags: (j['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    location: j['location'] as String?,
    createdAt: DateTime.parse(j['createdAt'] as String),
    modifiedAt: DateTime.parse(j['modifiedAt'] as String),
  );

  DiaryEntry copyWith({
    String? id,
    DateTime? eventDate,
    String? title,
    String? note,
    List<String>? tags,
    String? location,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) => DiaryEntry(
    id: id ?? this.id,
    eventDate: eventDate ?? this.eventDate,
    title: title ?? this.title,
    note: note ?? this.note,
    tags: tags ?? List<String>.from(this.tags),
    location: location ?? this.location,
    createdAt: createdAt ?? this.createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
  );

  @override
  String toString() => 'DiaryEntry($id, $eventDate, $title)';
}
