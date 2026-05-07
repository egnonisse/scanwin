import '../entities/ticket_extraction.dart';

class TicketParser {
  const TicketParser();

  TicketExtraction parse({
    required String rawText,
  }) {
    final text = rawText.replaceAll('\n', ' ').trim();

    // Identifiant ticket (approche très conservative pour éviter les faux positifs)
    final ticketIdRegExp = RegExp(
      r'(?:N\s*[°o]\s*ticket|N\s*[°o]\s*|No\s*|Nº\s*)([A-Z0-9][A-Z0-9\-]{4,})',
      caseSensitive: false,
    );
    final ticketId = ticketIdRegExp.firstMatch(text)?.group(1);

    // Montant total (format "12,50 €" ou "12.50€")
    final montantRegExp = RegExp(
      r'(\d+[.,]\d{2})\s*€',
      caseSensitive: false,
    );
    final montantMatch = montantRegExp.firstMatch(text);
    final montantTotal = montantMatch == null
        ? null
        : double.tryParse(
            montantMatch.group(1)!.replaceAll(',', '.'),
          );

    // Date (DD/MM/YYYY ou DD-MM-YYYY)
    final dateRegExp = RegExp(
      r'(\d{2}[\/\.\-]\d{2}[\/\.\-]\d{4})',
      caseSensitive: false,
    );
    final dateTicket = dateRegExp.firstMatch(text)?.group(1);

    // Enseigne / commerçant : heuristique (première ligne contenant des lettres)
    final firstLine = rawText.split(RegExp(r'\r?\n')).firstWhere(
      (line) => RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(line),
      orElse: () => '',
    );

    final enseigne = firstLine.isEmpty ? null : firstLine.trim();

    return TicketExtraction(
      rawText: rawText,
      ticketId: ticketId,
      montantTotal: montantTotal,
      dateTicket: dateTicket,
      enseigne: enseigne,
    );
  }
}

