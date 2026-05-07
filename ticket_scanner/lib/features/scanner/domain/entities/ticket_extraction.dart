class TicketExtraction {
  const TicketExtraction({
    required this.rawText,
    this.ticketId,
    this.montantTotal,
    this.dateTicket,
    this.enseigne,
    this.numeroCommande,
    this.modePaiement,
  });

  /// Texte OCR brut (utile pour débogage + fallback).
  final String rawText;

  /// Identifiant unique du ticket (N° ticket / code-barres).
  final String? ticketId;

  /// Montant total (si détecté).
  final double? montantTotal;

  /// Date du ticket (format libre, ex: DD/MM/YYYY).
  final String? dateTicket;

  final String? enseigne;
  final String? numeroCommande;
  final String? modePaiement;

  bool get isValidForMvp =>
      ticketId != null || montantTotal != null || dateTicket != null;
}

