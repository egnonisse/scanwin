import '../entities/pharmacy.dart';

/// Accès aux pharmacies pour la vue utilisateur.
abstract class PharmacyRepository {
  /// Flux des pharmacies (tri par nom par défaut).
  Stream<List<Pharmacy>> watchPharmacies();
}
