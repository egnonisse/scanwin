import 'package:cloud_functions/cloud_functions.dart';

import '../../features/scanner/domain/entities/receipt_extraction.dart';
import '../../features/scanner/domain/repositories/receipt_repository.dart';
import 'pending_receipt_store.dart';

/// Vide la file d'attente locale : soumet automatiquement les reçus
/// scannés hors ligne dès que le réseau est revenu (appelé au démarrage).
class OfflineQueueFlusher {
  OfflineQueueFlusher({
    required ReceiptRepository repository,
    PendingReceiptStore? store,
  })  : _repository = repository,
        _store = store ?? PendingReceiptStore();

  final ReceiptRepository _repository;
  final PendingReceiptStore _store;

  /// Soumet chaque reçu en attente (dans l'ordre). Un échec réseau stoppe
  /// la boucle (on retentera au prochain lancement). Retourne le nombre
  /// de reçus envoyés.
  Future<int> flush() async {
    final pending = await _store.loadAll();
    if (pending.isEmpty) return 0;

    var sent = 0;
    var index = 0;
    while (index < pending.length) {
      final receipt = pending[index];
      try {
        await _repository.submitReceipt(
          pharmacyName: receipt.pharmacyName,
          dateTicket: receipt.dateTicket,
          montant: receipt.montant,
          items: [
            for (final item in receipt.items)
              ReceiptItem(
                name: item['name'] as String? ?? '',
                price: (item['price'] as num?)?.toDouble() ?? 0,
                quantity: (item['quantity'] as num?)?.toInt() ?? 1,
              ),
          ],
        );
        await _store.removeAt(index);
        sent++;
        // NB : index ne bouge pas — removeAt décale la liste.
      } on ReceiptAlreadySubmittedException {
        // Déjà enregistré (double soumission) : retirer de la file.
        await _store.removeAt(index);
      } on ReceiptQueuedOfflineException {
        // Toujours hors ligne : on garde la file pour la prochaine fois.
        break;
      } on ReceiptSubmissionException {
        // Erreur serveur définitive (validation…) : retirer pour ne pas
        // bloquer la file indéfiniment.
        await _store.removeAt(index);
      } on FirebaseFunctionsException {
        // Réseau : on garde pour la prochaine fois.
        break;
      } catch (_) {
        break;
      }
    }
    return sent;
  }
}
