import '../entities/receipt_extraction.dart';

/// Parse le texte OCR d'un reçu de pharmacie (format Côte d'Ivoire, FCFA).
///
/// Le texte ML Kit peut être lu à l'envers (photo retournée) : on traite
/// chaque ligne indépendamment. Les prix FCFA ont des espaces ("1 500") et
/// peuvent être sur la ligne suivant le nom du médicament.
class ReceiptParser {
  const ReceiptParser();

  /// Nom + prix sur la même ligne (prix avec espaces optionnels).
  static final RegExp _itemRegExp = RegExp(
    r'^((?:[A-Za-zÀ-ÿ0-9][A-Za-zÀ-ÿ0-9 .\-/]*?))\s+(\d{1,3}(?:[ \u00A0]?\d{3})*(?:[.,]\d{1,2})?)\s*(?:FCFA|CFA|XOF|F|€)?\s*$',
    caseSensitive: false,
  );

  /// Ligne de prix pur (ex: "1 500", "1500", "1 500 F CFA").
  static final RegExp _priceLineRegExp = RegExp(
    r'^(\d{1,3}(?:[ \u00A0]?\d{3})*(?:[.,]\d{1,2})?)\s*(?:FCFA|CFA|XOF|F|€)?\s*$',
    caseSensitive: false,
  );

  /// Ligne de nom pur (sans prix) — candidate pour l'association ligne suivante.
  static final RegExp _nameLineRegExp = RegExp(
    r'^[A-Za-zÀ-ÿ0-9][A-Za-zÀ-ÿ0-9 .\-/]{2,}$',
    caseSensitive: false,
  );

  /// Nom + prix collés sans espace (ex: "MERC1500" — colonnes serrées).
  static final RegExp _gluedPriceRegExp = RegExp(
    r'^([A-Za-zÀ-ÿ]{2,})(\d{2,7})$',
    caseSensitive: false,
  );

  static final RegExp _totalRegExp = RegExp(
    r'\b(?:TOTAL|NET\s*[ÀA]\s*PAYER|[ÀA]\s*PAYER)\b[^0-9]*(\d[\d \u00A0]*(?:[.,]\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _dateRegExp = RegExp(
    r'(\d{2}[/.\-]\d{2}[/.\-]\d{4})',
    caseSensitive: false,
  );

  /// Heure : "21:15" ou "21 15". Doit être précédée d'un non-chiffre
  /// (sinon "2026 21" donnerait un faux "26 21" qui consomme la vraie heure).
  static final RegExp _heureRegExp = RegExp(
    r'(?:^|[^0-9])(\d{2})[: ](\d{2})',
    caseSensitive: false,
  );

  static const _keywordPatterns = [
    'total', 'montant', 'payer', 'rendu', 'arr', 'tva', 'remise',
    'espe', 'carte', 'date', 'facture', 'ticket', 'client', 'merci',
    'service', 'sold', 'avoir', 'ttc', 'ht', 'net', 'pharmacie',
    'qte', 'pu', 'verse', 'monnaie', 'reglement', 'valeur', 'caisse',
    'article', 'caissiere', 'tel', 'bp', 'souhait', 'remercie', 'confiance',
    'vendeur', 'especes',
  ];

  /// Somme des prix des items (fallback quand le reçu n'a pas de TOTAL).
  double? _sumItems(List<ReceiptItem> items) {
    if (items.isEmpty) return null;
    return items.fold<double>(0, (sum, item) => sum + item.price * item.quantity);
  }

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
    final heureTicket = _findHeure(fullText);
    final items = _findItems(lines);

    return ReceiptExtraction(
      rawText: rawText,
      pharmacyName: pharmacyName,
      montantTotal: montantTotal ?? _sumItems(items),
      dateTicket: dateTicket,
      heureTicket: heureTicket,
      items: items,
    );
  }

  String? _findPharmacyName(List<String> lines) {
    // Passe 1 : ligne contenant explicitement "pharmacie" (n'importe où —
    // le reçu peut être scanné à l'envers, la pharmacie est alors en bas).
    for (final line in lines) {
      if (line.toLowerCase().contains('pharmacie')) return line;
    }
    // Passe 2 : première ligne lettrée plausible.
    for (final line in lines) {
      if (!RegExp(r'[A-Za-zÀ-ÿ]{2}').hasMatch(line)) continue;
      if (line.length < 3) continue;
      if (_itemRegExp.hasMatch(line) || _priceLineRegExp.hasMatch(line)) {
        continue;
      }
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

  String? _findHeure(String fullText) {
    for (final match in _heureRegExp.allMatches(fullText)) {
      // Le regex exige déjà un non-chiffre avant l'heure (pas de "26 21").
      final hh = int.tryParse(match.group(1)!);
      final mm = int.tryParse(match.group(2)!);
      if (hh == null || mm == null || hh > 23 || mm > 59) continue;
      return '${match.group(1)}:${match.group(2)}';
    }
    return null;
  }

  List<ReceiptItem> _findItems(List<String> lines) {
    final items = <ReceiptItem>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_isKeyword(line)) continue;
      if (_isDeviseLine(line)) continue;

      // Cas 1 : nom + prix sur la même ligne.
      final sameLine = _itemRegExp.firstMatch(line);
      if (sameLine != null) {
        final rawName = sameLine.group(1)!.trim();
        if (!_isValidItemName(rawName)) continue;
        final price = _toDouble(sameLine.group(2));
        if (price == null || !_isPlausiblePrice(price)) continue;
        final (quantity, name) = _extractQuantity(rawName);
        items.add(ReceiptItem(name: name, price: price, quantity: quantity));
        continue;
      }

      // Cas 3 : nom + prix collés sans espace (ex: "MERC1500").
      final glued = _gluedPriceRegExp.firstMatch(line);
      if (glued != null) {
        final name = glued.group(1)!;
        if (!_isValidItemName(name)) continue;
        final price = _toDouble(glued.group(2));
        if (price == null || !_isPlausiblePrice(price)) continue;
        final (quantity, cleanName) = _extractQuantity(name);
        items.add(
          ReceiptItem(name: cleanName, price: price, quantity: quantity),
        );
        continue;
      }

      // Cas 2 : nom seul, prix sur la ligne suivante (reçus à colonnes).
      if (_nameLineRegExp.hasMatch(line) && !_priceLineRegExp.hasMatch(line)) {
        final rawName = line.trim();
        if (!_isValidItemName(rawName)) continue;

        final next = i + 1 < lines.length ? lines[i + 1] : '';
        final nextPrice = _priceLineRegExp.firstMatch(next);
        if (nextPrice == null) continue;
        final price = _toDouble(nextPrice.group(1));
        if (price == null || !_isPlausiblePrice(price)) continue;

        final (quantity, name) = _extractQuantity(rawName);
        items.add(ReceiptItem(name: name, price: price, quantity: quantity));
        i++; // la ligne de prix est consommée
        continue;
      }
    }

    return items;
  }

  /// Extrait le préfixe de quantité ("2X DOLIPRANE" -> (2, "DOLIPRANE")).
  (int, String) _extractQuantity(String rawName) {
    final match = RegExp(r'^(\d{1,2})\s*[xX×]\s*').firstMatch(rawName);
    if (match == null) return (1, rawName);
    final quantity = int.tryParse(match.group(1)!) ?? 1;
    return (quantity < 1 ? 1 : quantity, rawName.substring(match.end).trim());
  }

  bool _isValidItemName(String name) {
    // Un médicament a au moins 2 lettres consécutives (exclut "N 123456").
    if (!RegExp(r'[A-Za-zÀ-ÿ]{2}').hasMatch(name)) return false;
    if (name.length < 3) return false;
    return !_isKeyword(name);
  }

  bool _isPlausiblePrice(double price) {
    // En FCFA, un médicament coûte au minimum quelques centaines.
    return price >= 50 && price <= 1000000;
  }

  double? _toDouble(String? value) {
    if (value == null) return null;
    // Supprime les espaces des milliers ("1 500" -> "1500").
    final normalized = value.replaceAll(RegExp(r'[\s\u00A0]'), '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  bool _isKeyword(String line) {
    // Normalise les accents ("Règlement." -> "reglement.") pour matcher
    // les keywords français (règlement, versé, caissière...).
    final normalized = line
        .toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll('œ', 'oe');
    return _keywordPatterns.any((keyword) => normalized.contains(keyword));
  }

  /// Ligne de devise pure ("F CFA", "FCFA", "€") — jamais un médicament.
  bool _isDeviseLine(String line) {
    final compact = line.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return compact == 'fcfa' ||
        compact == 'cfa' ||
        compact == 'f' ||
        compact == '€' ||
        compact == 'f€';
  }
}
