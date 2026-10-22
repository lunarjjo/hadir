/// Model kantor (lokasi absen + radius geofence).
library;

class Office {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final bool active;
  final int createdAtMs;
  final int updatedAtMs;

  const Office({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.active,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  Office copyWith({
    String? name,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    bool? active,
    int? updatedAtMs,
  }) {
    return Office(
      id: id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      active: active ?? this.active,
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  factory Office.fromMap(Map<String, Object?> m) => Office(
        id: m['id'] as String,
        name: m['name'] as String,
        latitude: m['latitude'] as double,
        longitude: m['longitude'] as double,
        radiusMeters: m['radius_meters'] as int,
        active: (m['active'] as int) == 1,
        createdAtMs: m['created_at'] as int,
        updatedAtMs: m['updated_at'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
        'active': active ? 1 : 0,
        'created_at': createdAtMs,
        'updated_at': updatedAtMs,
      };
}
