import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/medication.dart';
import '../../domain/repositories/medication_repository.dart';

/// Implémentation Firestore : recherche par préfixe sur `name` (les noms
/// ANSM sont en majuscules — on normalise la requête en majuscules).
class FirebaseMedicationRepository implements MedicationRepository {
  const FirebaseMedicationRepository();

  @override
  Stream<List<Medication>> searchByName(String query) {
    final q = query.trim().toUpperCase();
    return FirebaseFirestore.instance
        .collection('medications')
        .where('name', isGreaterThanOrEqualTo: q)
        .where('name', isLessThanOrEqualTo: '$q\uf8ff')
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _fromDoc(doc.data()))
            .toList(growable: false));
  }

  Medication _fromDoc(Map<String, dynamic> data) {
    return Medication(
      name: data['name']?.toString() ?? '',
      form: data['form']?.toString(),
      routes: data['routes']?.toString(),
      titulaire: data['titulaire']?.toString(),
      dcis: (data['dcis'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }
}
