import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/price_entry.dart';
import '../../domain/repositories/price_repository.dart';

class FirebasePriceRepository implements PriceRepository {
  const FirebasePriceRepository();

  /// Normalise un nom (minuscules, sans accents) — même règle que la
  /// Cloud Function à la soumission.
  static String normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  @override
  Stream<List<PriceEntry>> searchByMedication(String query) {
    final normalized = normalize(query);
    if (normalized.isEmpty) return Stream.value(const []);

    final ref = FirebaseFirestore.instance
        .collection('priceEntries')
        .where('medicationName', isGreaterThanOrEqualTo: normalized)
        .where('medicationName', isLessThanOrEqualTo: '$normalized\uf8ff')
        .orderBy('medicationName')
        .orderBy('price')
        .limit(30);

    return ref.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => PriceEntryModel.fromDoc(doc).toEntity())
              .toList(growable: false),
        );
  }
}

class PriceEntryModel {
  const PriceEntryModel({
    required this.id,
    required this.medicationName,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.price,
    required this.quantity,
    required this.scannedAt,
  });

  final String id;
  final String medicationName;
  final String pharmacyId;
  final String? pharmacyName;
  final num price;
  final num quantity;
  final Timestamp? scannedAt;

  PriceEntry toEntity() {
    return PriceEntry(
      id: id,
      medicationName: medicationName,
      pharmacyId: pharmacyId,
      pharmacyName: pharmacyName,
      price: price.toDouble(),
      quantity: quantity.toInt(),
      scannedAt: scannedAt?.toDate(),
    );
  }

  static PriceEntryModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PriceEntryModel(
      id: doc.id,
      medicationName: data['medicationName'] as String? ?? '',
      pharmacyId: data['pharmacyId'] as String? ?? '',
      pharmacyName: data['pharmacyName'] as String?,
      price: data['price'] as num? ?? 0,
      quantity: data['quantity'] as num? ?? 1,
      scannedAt: data['scannedAt'] as Timestamp?,
    );
  }
}
