import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/receipt_extraction.dart';

/// Analyse d'un reçu par IA (Cloud Function parseReceiptWithAI → DeepSeek).
///
/// Le LLM reconstruit le reçu à partir du texte OCR brut (montants, dates,
/// items, quantités). L'image n'est JAMAIS envoyée ici — texte seul.
class ReceiptAiParser {
  ReceiptAiParser({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  /// Retourne une extraction structurée, ou null si l'IA échoue
  /// (l'appelant doit alors utiliser le parser local en fallback).
  Future<ReceiptExtraction?> parse({required String rawText}) async {
    if (rawText.trim().length < 20) return null;
    try {
      final callable = _functions.httpsCallable('parseReceiptWithAI');
      final response = await callable.call({'rawText': rawText});
      final data = Map<String, dynamic>.from(response.data as Map);

      final rawItems = (data['items'] as List?) ?? const [];
      final items = rawItems
          .map((item) => Map<String, dynamic>.from(item as Map))
          .map((item) => ReceiptItem(
                name: (item['name'] as String?)?.trim() ?? '',
                price: (item['price'] as num?)?.toDouble() ?? 0,
                quantity: (item['qty'] as num?)?.toInt() ?? 1,
              ))
          .where((item) => item.name.isNotEmpty && item.price > 0)
          .toList();

      return ReceiptExtraction(
        rawText: rawText,
        pharmacyName: (data['pharmacyName'] as String?)?.trim(),
        dateTicket: data['dateTicket'] as String?,
        heureTicket: data['heure'] as String?,
        montantTotal: (data['total'] as num?)?.toDouble(),
        items: items,
      );
    } catch (_) {
      return null;
    }
  }
}
