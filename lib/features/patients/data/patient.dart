import 'package:dental_clinic/core/api/api_client.dart';

/// A clinic patient. The API model supports only name and phone number.
class Patient {
  const Patient({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.status,
    required this.version,
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

  factory Patient.fromJson(JsonMap json) {
    return Patient(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      phoneNumber: (json['phoneNumber'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'active',
      version: (json['version'] as String?) ?? '',
      archivedAt: json['archivedAt'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Patient copyWith({String? name, String? phoneNumber, String? status, String? version}) {
    return Patient(
      id: id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      status: status ?? this.status,
      version: version ?? this.version,
      archivedAt: archivedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
