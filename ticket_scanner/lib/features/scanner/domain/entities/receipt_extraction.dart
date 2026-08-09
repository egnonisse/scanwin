/// Une ligne de médicament extraite d'un reçu de pharmacie.
class ReceiptItem {
  const ReceiptItem({
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  final String name;
  final double price;
  final int quantity;
}

/// Résultat de l'extraction OCR d'un reçu de pharmacie.
class ReceiptExtraction {
  const ReceiptExtraction({
    required this.rawText,
    this.pharmacyName,
    this.dateTicket,
    this.montantTotal,
    this.items = const [],
  });

  /// Texte OCR brut (utile pour débogage + fallback).
  final String rawText;

  /// Nom de la pharmacie (heuristique : première ligne significative).
  final String? pharmacyName;

  /// Date du reçu (format libre, ex: DD/MM/YYYY).
  final String? dateTicket;

  /// Montant total (si détecté).
  final double? montantTotal;

  /// Lignes de médicaments extraites.
  final List<ReceiptItem> items;

  bool get isValidForMvp =>
      pharmacyName != null || montantTotal != null || items.isNotEmpty;
}
