/// Reçu soumis (modération admin).
class ReceiptDoc {
  const ReceiptDoc({
    required this.id,
    required this.pharmacyId,
    required this.montant,
    required this.dateTicket,
    required this.scannedAt,
    required this.itemCount,
    required this.items,
  });

  final String id;
  final String pharmacyId;
  final double montant;
  final DateTime? dateTicket;
  final DateTime? scannedAt;
  final int itemCount;
  final List<ReceiptItemDoc> items;
}

class ReceiptItemDoc {
  const ReceiptItemDoc({
    required this.name,
    required this.price,
    required this.quantity,
  });

  final String name;
  final double price;
  final int quantity;
}
