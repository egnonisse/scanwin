import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../domain/entities/receipt_extraction.dart';
import '../../domain/repositories/receipt_repository.dart';

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
    String? photoPath;
    if (imagePath != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final ref = FirebaseStorage.instance.ref(
          'pending/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await ref.putFile(File(imagePath));
        photoPath = ref.fullPath;
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
      // Propage le message serveur (ex: "Nom de médicament invalide").
      final detail = e.message;
      throw ReceiptSubmissionException(
        detail: (detail == null || detail.isEmpty)
            ? null
            : detail,
      );
    }
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
      final callable = FirebaseFunctions.instance.httpsCallable('submitReceipt');
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
