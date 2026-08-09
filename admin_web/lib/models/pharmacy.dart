/// Pharmacie (CRUD admin).
class Pharmacy {
  const Pharmacy({
    required this.id,
    required this.name,
    this.address,
    this.commune,
    this.lat,
    this.lng,
    this.onDutyDates = const [],
  });

  final String id;
  final String name;
  final String? address;
  final String? commune;
  final double? lat;
  final double? lng;

  /// Dates de garde au format ISO (yyyy-MM-dd).
  final List<String> onDutyDates;

  Pharmacy copyWith({
    String? name,
    String? address,
    String? commune,
    double? lat,
    double? lng,
    List<String>? onDutyDates,
  }) {
    return Pharmacy(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      commune: commune ?? this.commune,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      onDutyDates: onDutyDates ?? this.onDutyDates,
    );
  }
}
