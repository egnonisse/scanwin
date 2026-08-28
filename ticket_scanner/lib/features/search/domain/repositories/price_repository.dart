import '../entities/price_entry.dart';

abstract class PriceRepository {
  /// Recherche les prix d'un médicament par préfixe de nom normalisé,
  /// triés par prix croissant (temps réel).
  Stream<List<PriceEntry>> searchByMedication(String query);

  /// Médicaments populaires (prix officiels récents, dédupliqués) —
  /// affichés par défaut quand la recherche est vide.
  Stream<List<PriceEntry>> watchPopularMeds();
}
