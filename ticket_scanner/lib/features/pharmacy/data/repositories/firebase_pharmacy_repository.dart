import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/pharmacy.dart';
import '../../domain/repositories/pharmacy_repository.dart';

class FirebasePharmacyRepository implements PharmacyRepository {
  const FirebasePharmacyRepository();

  @override
  Stream<List<Pharmacy>> watchPharmacies() {
    return FirebaseFirestore.instance
        .collection('pharmacies')
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PharmacyModel.fromDoc(doc).toEntity())
              .toList(growable: false),
        );
  }
}

class PharmacyModel {
  const PharmacyModel({
    required this.id,
    required this.name,
    this.address,
    this.commune,
    this.phone1,
    this.phone2,
    this.lat,
    this.lng,
    required this.onDutyDates,
  });

  final String id;
  final String name;
  final String? address;
  final String? commune;
  final String? phone1;
  final String? phone2;
  final double? lat;
  final double? lng;
  final List<String> onDutyDates;

  Pharmacy toEntity() {
    return Pharmacy(
      id: id,
      name: name,
      address: address,
      commune: commune,
      phone1: phone1,
      phone2: phone2,
      lat: lat,
      lng: lng,
      onDutyDates: onDutyDates,
    );
  }

  static PharmacyModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PharmacyModel(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      address: data['address'] as String?,
      commune: data['commune'] as String?,
      phone1: data['phone1'] as String?,
      phone2: data['phone2'] as String?,
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
      onDutyDates:
          (data['onDutyDates'] as List?)?.cast<String>() ?? const [],
    );
  }
}
