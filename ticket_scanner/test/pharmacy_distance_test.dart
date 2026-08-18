import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_scanner/features/pharmacy/domain/entities/pharmacy.dart';

void main() {
  group('PharmacyDistance.haversine', () {
    test('distance nulle pour deux points identiques', () {
      expect(PharmacyDistance.haversine(5.32, -4.02, 5.32, -4.02), 0.0);
    });

    test('distance Abidjan Plateau -> Cocody (ordre de grandeur ~5-8 km)', () {
      // Plateau (5.3232, -4.0174) → Cocody (5.3486, -3.9901)
      final km = PharmacyDistance.haversine(5.3232, -4.0174, 5.3486, -3.9901);
      expect(km, greaterThan(3));
      expect(km, lessThan(10));
    });

    test('symétrique (A->B == B->A)', () {
      final ab = PharmacyDistance.haversine(5.32, -4.02, 6.13, 1.22);
      final ba = PharmacyDistance.haversine(6.13, 1.22, 5.32, -4.02);
      expect(ab, closeTo(ba, 1e-9));
    });
  });

  group('Pharmacy.distanceKmFrom / isOnDutyOn', () {
    const pharmacy = Pharmacy(
      id: 'p1',
      name: 'PHARMACIE TEST',
      lat: 5.3486,
      lng: -3.9901,
      commune: 'Cocody',
      onDutyDates: ['2026-08-16'],
    );

    test('distance depuis un point proche', () {
      final km = pharmacy.distanceKmFrom(5.3232, -4.0174);
      expect(km, isNotNull);
      expect(km!, greaterThan(3));
      expect(km, lessThan(10));
    });

    test('de garde sur la date listée', () {
      expect(pharmacy.isOnDutyOn('2026-08-16'), isTrue);
      expect(pharmacy.isOnDutyOn('2026-08-17'), isFalse);
    });

    test('null si la pharmacie n\'a pas de GPS', () {
      const noGps = Pharmacy(id: 'p2', name: 'SANS GPS');
      expect(noGps.distanceKmFrom(5.32, -4.02), isNull);
    });
  });
}
