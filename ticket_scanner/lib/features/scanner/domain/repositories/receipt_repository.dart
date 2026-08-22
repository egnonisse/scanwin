import '../entities/receipt_extraction.dart';

/// Erreur métier : le reçu a déjà été soumis (unicité).
class ReceiptAlreadySubmittedException implements Exception {
  const ReceiptAlreadySubmittedException();
}

/// Erreur générique de soumission (réseau, serveur, validation).
class ReceiptSubmissionException implements Exception {
  const ReceiptSubmissionException({this.detail});

  /// Message détaillé du serveur (si disponible).
  final String? detail;

  @override
  String toString() => detail ?? 'Erreur de soumission du reçu.';
}

/// Le reçu n'a PAS pu être soumis (hors ligne) et a été mis en file
/// d'attente locale : il sera envoyé automatiquement au retour du réseau.
class ReceiptQueuedOfflineException implements Exception {
  const ReceiptQueuedOfflineException();
}

abstract class ReceiptRepository {
  /// Soumet un reçu de pharmacie via la Cloud Function [submitReceipt].
  ///
  /// Retourne le nombre de points ajoutés.
  /// Lance [ReceiptAlreadySubmittedException] si le reçu existe déjà,
  /// [ReceiptSubmissionException] pour toute autre erreur.
  Future<int> submitReceipt({
    required String pharmacyName,
    required String dateTicket,
    required double montant,
    required List<ReceiptItem> items,
    String? imagePath,
  });
}
