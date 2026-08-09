/// Une entrée de prix (1 ligne de médicament d'un reçu soumis).
class PriceEntry {
  const PriceEntry({
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

  /// Nom de la pharmacie (dénormalisé à la soumission pour éviter les N+1).
  final String? pharmacyName;
  final double price;
  final int quantity;
  final DateTime? scannedAt;
}
