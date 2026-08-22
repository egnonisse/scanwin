import '../entities/medication.dart';

/// Référentiel de médicaments (sans prix) — recherche dans la base ANSM.
abstract class MedicationRepository {
  /// Recherche par préfixe de nom (insensible à la casse côté client).
  Stream<List<Medication>> searchByName(String query);
}
