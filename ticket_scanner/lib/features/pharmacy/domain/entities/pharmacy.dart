import 'dart:math' as math;

/// Pharmacie (vue utilisateur).
class Pharmacy {
  const Pharmacy({
    required this.id,
    required this.name,
    this.address,
    this.commune,
    this.phone1,
    this.phone2,
    this.lat,
    this.lng,
    this.onDutyDates = const [],
  });

  final String id;
  final String name;
  final String? address;
  final String? commune;
  final String? phone1;
  final String? phone2;
  final double? lat;
  final double? lng;

  /// Dates de garde au format ISO (yyyy-MM-dd).
  final List<String> onDutyDates;

  /// True si la pharmacie est de garde à la date donnée (ISO yyyy-MM-dd).
  bool isOnDutyOn(String isoDate) => onDutyDates.contains(isoDate);

  /// Distance en km depuis un point (null si la pharmacie n'a pas de GPS).
  double? distanceKmFrom(double userLat, double userLng) {
    if (lat == null || lng == null) return null;
    return PharmacyDistance.haversine(userLat, userLng, lat!, lng!);
  }
}

/// Calcul de distance (formule de Haversine).
class PharmacyDistance {
  const PharmacyDistance._();

  static const double _earthRadiusKm = 6371.0;

  /// Distance à vol d'oiseau en km entre deux points GPS.
  static double haversine(double lat1, double lng1, double lat2, double lng2) {
    const r = _earthRadiusKm;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRadians(double deg) => deg * math.pi / 180.0;
}
