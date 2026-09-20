import 'package:dental_clinic/core/api/api_client.dart';

/// One previous credit value, as stored by the API in `creditHistory`.
///
/// The server appends the *old* value (and when it was set) each time the
/// credit changes, so the list is chronological, oldest first.
class CreditHistoryEntry {
  const CreditHistoryEntry({required this.value, this.enteredAt});

  /// Credit balance in integer hundredths of JOD.
  final int value;

  /// ISO-8601 timestamp of when this value was set.
  final String? enteredAt;

  factory CreditHistoryEntry.fromJson(JsonMap json) {
    return CreditHistoryEntry(
      value: (json['value'] as num?)?.toInt() ?? 0,
      enteredAt: json['enteredAt'] as String?,
    );
  }
}

/// One step in the credit timeline, ready for display: the balance after the
/// change and how much it moved by.
class CreditChange {
  const CreditChange({
    required this.balance,
    required this.delta,
    required this.isStartingBalance,
    this.at,
  });

  /// Balance after this change (hundredths of JOD).
  final int balance;

  /// Signed change from the previous balance (hundredths of JOD). For the
  /// starting balance this equals [balance].
  final int delta;

  /// True for the oldest entry we know about, which has no previous value.
  final bool isStartingBalance;

  final DateTime? at;

  bool get isIncrease => !isStartingBalance && delta > 0;
  bool get isDeduction => !isStartingBalance && delta < 0;
}

/// A clinic patient.
class Patient {
  const Patient({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.status,
    required this.version,
    this.credit = 0,
    this.creditUpdatedAt,
    this.creditHistory = const [],
    this.archivedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String phoneNumber;

  /// 'active' or 'archived'.
  final String status;

  /// Optimistic-concurrency token (derived from Cosmos `_etag`). Sent back as
  /// the `If-Match` header on updates, archive, restore and purge.
  final String version;

  /// Current credit balance in integer hundredths of JOD. Never negative.
  final int credit;

  /// ISO-8601 timestamp of when [credit] was last set, or null for legacy
  /// patients whose credit has never been set.
  final String? creditUpdatedAt;

  /// Previous credit values, oldest first (server keeps the latest 50).
  final List<CreditHistoryEntry> creditHistory;

  final String? archivedAt;
  final String? createdAt;
  final String? updatedAt;

  bool get isArchived => status == 'archived';

  /// Up to two initials for the avatar, derived from the name.
  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    String firstRune(String s) => String.fromCharCode(s.runes.first);
    if (parts.length == 1) {
      final runes = parts.first.runes.toList();
      final take = runes.take(2).map(String.fromCharCode).join();
      return take.toUpperCase();
    }
    return '${firstRune(parts.first)}${firstRune(parts.last)}'.toUpperCase();
  }

  /// The credit history combined with the current balance, newest first, with
  /// the increase/deduction computed for each step.
  ///
  /// Returns an empty list when there is nothing meaningful to show (no
  /// history and a zero or never-set balance).
  List<CreditChange> get creditTimeline {
    final points = <({int value, String? at})>[
      for (final entry in creditHistory) (value: entry.value, at: entry.enteredAt),
      if (creditUpdatedAt != null || creditHistory.isNotEmpty)
        (value: credit, at: creditUpdatedAt),
    ];

    if (points.isEmpty) return const [];
    if (points.length == 1 && points.first.value == 0) return const [];

    final changes = <CreditChange>[];
    for (var i = 0; i < points.length; i++) {
      final isFirst = i == 0;
      final previous = isFirst ? 0 : points[i - 1].value;
      changes.add(CreditChange(
        balance: points[i].value,
        delta: points[i].value - previous,
        isStartingBalance: isFirst,
        at: points[i].at == null ? null : DateTime.tryParse(points[i].at!),
      ));
    }
    return changes.reversed.toList();
  }

  factory Patient.fromJson(JsonMap json) {
    final rawCredit = (json['credit'] as num?)?.toInt() ?? 0;
    final rawHistory = json['creditHistory'];
    return Patient(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      phoneNumber: (json['phoneNumber'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'active',
      version: (json['version'] as String?) ?? '',
      credit: rawCredit < 0 ? 0 : rawCredit,
      creditUpdatedAt: json['creditUpdatedAt'] as String?,
      creditHistory: rawHistory is List
          ? rawHistory
              .whereType<Map>()
              .map((e) => CreditHistoryEntry.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
      archivedAt: json['archivedAt'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Patient copyWith({
    String? name,
    String? phoneNumber,
    String? status,
    String? version,
  }) {
    return Patient(
      id: id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      status: status ?? this.status,
      version: version ?? this.version,
      credit: credit,
      creditUpdatedAt: creditUpdatedAt,
      creditHistory: creditHistory,
      archivedAt: archivedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
