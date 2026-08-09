import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pharmacy.dart';
import '../models/receipt_doc.dart';

/// Accès Firestore pour l'admin (les règles vérifient l'email admin).
class FirestoreService {
  const FirestoreService();

  static const _pharmacies = 'pharmacies';
  static const _receipts = 'receipts';
  static const _priceEntries = 'priceEntries';

  // --- Pharmacies ---

  Stream<List<Pharmacy>> watchPharmacies() {
    return FirebaseFirestore.instance
        .collection(_pharmacies)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _pharmacyFromDoc(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Future<void> createPharmacy(Pharmacy pharmacy) async {
    await FirebaseFirestore.instance
        .collection(_pharmacies)
        .add(_pharmacyToMap(pharmacy));
  }

  Future<void> updatePharmacy(Pharmacy pharmacy) async {
    await FirebaseFirestore.instance
        .collection(_pharmacies)
        .doc(pharmacy.id)
        .set(_pharmacyToMap(pharmacy));
  }

  Future<void> deletePharmacy(String id) async {
    await FirebaseFirestore.instance.collection(_pharmacies).doc(id).delete();
  }

  // --- Reçus (modération) ---

  Stream<List<ReceiptDoc>> watchReceipts({int limit = 50}) {
    return FirebaseFirestore.instance
        .collection(_receipts)
        .orderBy('scannedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _receiptFromDoc(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  /// Supprime un reçu et ses entrées de prix (cascade manuelle).
  Future<void> deleteReceipt(String receiptId) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final entries = await firestore
        .collection(_priceEntries)
        .where('receiptId', isEqualTo: receiptId)
        .get();
    for (final entry in entries.docs) {
      batch.delete(entry.reference);
    }

    batch.delete(firestore.collection(_receipts).doc(receiptId));
    await batch.commit();
  }

  // --- Stats ---

  Future<int> countPharmacies() async {
    final snapshot = await FirebaseFirestore.instance
        .collection(_pharmacies)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<int> countReceipts() async {
    final snapshot =
        await FirebaseFirestore.instance.collection(_receipts).count().get();
    return snapshot.count ?? 0;
  }

  Future<int> countPriceEntries() async {
    final snapshot = await FirebaseFirestore.instance
        .collection(_priceEntries)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // --- Mapping ---

  Pharmacy _pharmacyFromDoc(String id, Map<String, dynamic> data) {
    return Pharmacy(
      id: id,
      name: data['name'] as String? ?? '',
      address: data['address'] as String?,
      commune: data['commune'] as String?,
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
      onDutyDates:
          (data['onDutyDates'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> _pharmacyToMap(Pharmacy pharmacy) {
    return {
      'name': pharmacy.name,
      'address': pharmacy.address,
      'commune': pharmacy.commune,
      'lat': pharmacy.lat,
      'lng': pharmacy.lng,
      'onDutyDates': pharmacy.onDutyDates,
    };
  }

  ReceiptDoc _receiptFromDoc(String id, Map<String, dynamic> data) {
    final rawItems = data['items'] as List? ?? const [];
    final items = rawItems
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (item) => ReceiptItemDoc(
            name: item['name'] as String? ?? '',
            price: (item['price'] as num?)?.toDouble() ?? 0,
            quantity: (item['quantity'] as num?)?.toInt() ?? 1,
          ),
        )
        .toList(growable: false);

    return ReceiptDoc(
      id: id,
      pharmacyId: data['pharmacyId'] as String? ?? '',
      montant: (data['montant'] as num?)?.toDouble() ?? 0,
      dateTicket: _toDate(data['dateTicket']),
      scannedAt: _toDate(data['scannedAt']),
      itemCount: (data['itemCount'] as num?)?.toInt() ?? items.length,
      items: items,
    );
  }

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
