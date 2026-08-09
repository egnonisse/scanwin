import '../entities/receipt_extraction.dart';

/// Parse le texte OCR d'un reçu de pharmacie (format Côte d'Ivoire, FCFA).
///
/// Approche conservative : le parser n'a pas besoin d'être parfait,
/// l'utilisateur corrige les champs dans l'écran de confirmation.
class ReceiptParser {
  const ReceiptParser();

  static final RegExp _itemRegExp = RegExp(
    r'^((?:[A-Za-zÀ-ÿ0-9][A-Za-zÀ-ÿ0-9 .\-/]*?))\s+(\d{1,7}(?:[.,]\d{1,2})?)\s*(?:FCFA|CFA|XOF|F|€)?\s*$',
    caseSensitive: false,
  );

  static final RegExp _totalRegExp = RegExp(
    r'(?:TOTAL|MONTANT|À\s*PAYER|A\s*PAYER)\b[^0-9]*(\d{1,7}(?:[.,]\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _dateRegExp = RegExp(
    r'(\d{2}[/.\-]\d{2}[/.\-]\d{4})',
    caseSensitive: false,
  );

  static final RegExp _quantityRegExp = RegExp(
    r'^(\d{1,2})\s*[xX×]\s*',
  );

  static const _keywordPatterns = [
    'total', 'montant', 'payer', 'rendu', 'arr', 'tva', 'remise',
    'espe', 'carte', 'date', 'facture', 'ticket', 'client', 'merci',
    'service', 'sold', 'avoir', 'ttc', 'ht', 'net', 'pharmacie',
  ];

  ReceiptExtraction parse({required String rawText}) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final fullText = lines.join(' ');

    final pharmacyName = _findPharmacyName(lines);
    final montantTotal = _findMontantTotal(fullText);
    final dateTicket = _dateRegExp.firstMatch(fullText)?.group(1);
    final items = _findItems(lines);

    return ReceiptExtraction(
      rawText: rawText,
      pharmacyName: pharmacyName,
      montantTotal: montantTotal,
      dateTicket: dateTicket,
      items: items,
    );
  }

  String? _findPharmacyName(List<String> lines) {
    for (final line in lines) {
      if (!RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(line)) continue;
      if (line.length < 3) continue;
      final lower = line.toLowerCase();
      // Priorité : la ligne contient explicitement "pharmacie".
      if (lower.contains('pharmacie')) return line;
      // Une ligne de médicament (nom + prix) n'est pas le nom de la pharmacie.
      if (_itemRegExp.hasMatch(line)) continue;
      if (_isKeyword(line)) continue;
      return line;
    }
    return null;
  }

  double? _findMontantTotal(String fullText) {
    final match = _totalRegExp.firstMatch(fullText);
    if (match == null) return null;
    return _toDouble(match.group(1));
  }

  List<ReceiptItem> _findItems(List<String> lines) {
    final items = <ReceiptItem>[];

    for (final line in lines) {
      if (_isKeyword(line)) continue;

      final match = _itemRegExp.firstMatch(line);
      if (match == null) continue;

      final rawName = match.group(1)!.trim();
      // Une ligne purement numérique (date, quantité) n'est pas un médicament.
      // Un médicament a au moins 2 lettres consécutives (exclut "N 123456").
      if (!RegExp(r'[A-Za-zÀ-ÿ]{2}').hasMatch(rawName)) continue;

      final price = _toDouble(match.group(2));
      if (price == null || !_isPlausiblePrice(price)) continue;

      final quantity = _extractQuantity(line);
      final name = quantity > 1
          ? rawName.replaceFirst(RegExp(r'^\d{1,2}\s*[xX×]\s*'), '').trim()
          : rawName;

      items.add(
        ReceiptItem(
          name: name,
          price: price,
          quantity: quantity,
        ),
      );
    }

    return items;
  }

  int _extractQuantity(String line) {
    final match = _quantityRegExp.firstMatch(line);
    if (match == null) return 1;
    final quantity = int.tryParse(match.group(1)!);
    return (quantity == null || quantity < 1) ? 1 : quantity;
  }

  bool _isPlausiblePrice(double price) {
    // En FCFA, un médicament coûte au minimum quelques centaines.
    return price >= 50 && price <= 1000000;
  }

  double? _toDouble(String? value) {
    if (value == null) return null;
    return double.tryParse(value.replaceAll(',', '.'));
  }

  bool _isKeyword(String line) {
    final lower = line.toLowerCase();
    return _keywordPatterns.any((keyword) => lower.contains(keyword));
  }
}
