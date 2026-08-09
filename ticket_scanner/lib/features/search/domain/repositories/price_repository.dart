import '../entities/price_entry.dart';

abstract class PriceRepository {
  /// Recherche les prix d'un médicament par préfixe de nom normalisé,
  /// triés par prix croissant (temps réel).
  Stream<List<PriceEntry>> searchByMedication(String query);
}
