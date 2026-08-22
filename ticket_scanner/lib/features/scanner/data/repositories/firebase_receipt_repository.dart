import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/offline/pending_receipt_store.dart';
import '../../domain/entities/receipt_extraction.dart';
import '../../domain/repositories/receipt_repository.dart';

/// Codes Cloud Functions = indisponibilité réseau (→ file d'attente).
const _networkCodes = {
  'unavailable',
  'deadline-exceeded',
  'internal',
  'resource-exhausted',
  'unknown',
  'aborted',
};

class FirebaseReceiptRepository implements ReceiptRepository {
  const FirebaseReceiptRepository();

  @override
  Future<int> submitReceipt({
    required String pharmacyName,
    required String dateTicket,
    required double montant,
    required List<ReceiptItem> items,
    String? imagePath,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable('submitReceipt');

    // Upload de la photo dans Storage (dossier temporaire pending/).
    // La Cloud Function la déplacera vers receipts/{hash}.jpg après validation.
    // Hors ligne, l'upload échoue : on soumet SANS photo (toléré).
    String? photoPath;
    if (imagePath != null) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final ref = FirebaseStorage.instance.ref(
            'pending/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          await ref.putFile(File(imagePath));
          photoPath = ref.fullPath;
        }
      } catch (_) {
        // Réseau absent : la soumission partira sans photo.
        photoPath = null;
      }
    }

    try {
      final result = await callable.call({
        'pharmacyName': pharmacyName,
        'dateTicket': dateTicket,
        'montant': montant,
        'items': [
          for (final item in items)
            {'name': item.name, 'price': item.price, 'quantity': item.quantity},
        ],
        if (photoPath != null) 'photoPath': photoPath,
      });
      final data = result.data;
      if (data is Map && data['pointsAdded'] is num) {
        return (data['pointsAdded'] as num).toInt();
      }
      throw const ReceiptSubmissionException();
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists') {
        throw const ReceiptAlreadySubmittedException();
      }
      if (e.code == 'unauthenticated') {
        // Token expiré (réseau instable) : on ré-authentifie et on retente
        // une seule fois avant d'abandonner.
        final retried = await _retryWithFreshAuth(
          pharmacyName: pharmacyName,
          dateTicket: dateTicket,
          montant: montant,
          items: items,
          photoPath: photoPath,
        );
        if (retried != null) return retried;
      }
      if (_networkCodes.contains(e.code)) {
        // Hors ligne : file d'attente locale, envoi automatique plus tard.
        await _queueOffline(
          pharmacyName: pharmacyName,
          dateTicket: dateTicket,
          montant: montant,
          items: items,
        );
        throw const ReceiptQueuedOfflineException();
      }
      // Propage le message serveur (ex: "Nom de médicament invalide").
      final detail = e.message;
      throw ReceiptSubmissionException(
        detail: (detail == null || detail.isEmpty) ? null : detail,
      );
    } catch (e) {
      // Erreur réseau pure (SocketException, TimeoutException…) : file.
      if (e is ReceiptQueuedOfflineException) rethrow;
      await _queueOffline(
        pharmacyName: pharmacyName,
        dateTicket: dateTicket,
        montant: montant,
        items: items,
      );
      throw const ReceiptQueuedOfflineException();
    }
  }

  /// Sauvegarde le reçu en file d'attente locale (hors ligne).
  Future<void> _queueOffline({
    required String pharmacyName,
    required String dateTicket,
    required double montant,
    required List<ReceiptItem> items,
  }) async {
    final store = PendingReceiptStore();
    await store.add(PendingReceipt(
      pharmacyName: pharmacyName,
      dateTicket: dateTicket,
      montant: montant,
      items: [
        for (final item in items)
          {'name': item.name, 'price': item.price, 'quantity': item.quantity},
      ],
    ));
  }

  /// Ré-authentifie l'utilisateur anonyme et retente la soumission.
  Future<int?> _retryWithFreshAuth({
    required String pharmacyName,
    required String dateTicket,
    required double montant,
    required List<ReceiptItem> items,
    String? photoPath,
  }) async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
      final callable =
          FirebaseFunctions.instance.httpsCallable('submitReceipt');
      final result = await callable.call({
        'pharmacyName': pharmacyName,
        'dateTicket': dateTicket,
        'montant': montant,
        'items': [
          for (final item in items)
            {'name': item.name, 'price': item.price, 'quantity': item.quantity},
        ],
        if (photoPath != null) 'photoPath': photoPath,
      });
      final data = result.data;
      if (data is Map && data['pointsAdded'] is num) {
        return (data['pointsAdded'] as num).toInt();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
