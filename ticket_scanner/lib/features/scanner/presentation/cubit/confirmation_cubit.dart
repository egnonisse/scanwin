import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/receipt_extraction.dart';
import '../../domain/repositories/receipt_repository.dart';
import 'confirmation_state.dart';

class ConfirmationCubit extends Cubit<ConfirmationState> {
  ConfirmationCubit({required ReceiptRepository repository})
      : _repository = repository,
        super(const ConfirmationState.initial());

  final ReceiptRepository _repository;

  /// Convertit "31/03/2025" (format reçus) en ISO 8601.
  /// Retourne null si le format n'est pas reconnu.
  static String? toIsoDate(String? value) {
    if (value == null) return null;
    final match =
        RegExp(r'^(\d{2})[/.\-](\d{2})[/.\-](\d{4})$').firstMatch(value.trim());
    if (match == null) return null;
    return '${match.group(3)}-${match.group(2)}-${match.group(1)}';
  }

  Future<void> submit({
    required String pharmacyName,
    required String dateText,
    required String montantText,
    required List<ReceiptItem> items,
    String? imagePath,
  }) async {
    final name = pharmacyName.trim();
    if (name.length < 3) {
      emit(
        state.copyWith(
          status: ConfirmationStatus.error,
          errorMessage: 'Nom de pharmacie invalide.',
        ),
      );
      return;
    }

    final dateTicket = toIsoDate(dateText);
    if (dateTicket == null) {
      emit(
        state.copyWith(
          status: ConfirmationStatus.error,
          errorMessage: 'Date invalide (format attendu : 31/03/2025).',
        ),
      );
      return;
    }

    final montant = double.tryParse(montantText.trim().replaceAll(',', '.'));
    if (montant == null || montant <= 0) {
      emit(
        state.copyWith(
          status: ConfirmationStatus.error,
          errorMessage: 'Montant total invalide.',
        ),
      );
      return;
    }

    final validItems = items.where((item) => item.price > 0).toList();
    if (validItems.isEmpty) {
      emit(
        state.copyWith(
          status: ConfirmationStatus.error,
          errorMessage: 'Ajoute au moins une ligne de médicament.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: ConfirmationStatus.submitting,
        errorMessage: null,
      ),
    );

    try {
      final points = await _repository.submitReceipt(
        pharmacyName: name,
        dateTicket: dateTicket,
        montant: montant,
        items: validItems,
        imagePath: imagePath,
      );
      emit(
        state.copyWith(
          status: ConfirmationStatus.success,
          pointsAdded: points,
        ),
      );
    } on ReceiptAlreadySubmittedException {
      emit(
        state.copyWith(
          status: ConfirmationStatus.error,
          errorMessage: 'Ce reçu a déjà été soumis.',
        ),
      );
    } on ReceiptQueuedOfflineException {
      // Hors ligne : le reçu est en file d'attente locale et sera envoyé
      // automatiquement au retour du réseau. C'est un succès différé.
      emit(
        state.copyWith(
          status: ConfirmationStatus.queuedOffline,
        ),
      );
    } on ReceiptSubmissionException catch (e) {
      emit(
        state.copyWith(
          status: ConfirmationStatus.error,
          errorMessage: e.detail ??
              'Impossible de soumettre le reçu. Vérifie ta connexion et réessaie.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ConfirmationStatus.error,
          errorMessage:
              'Impossible de soumettre le reçu. Vérifie ta connexion et réessaie.',
        ),
      );
    }
  }

  /// Remet le cubit à son état initial (après une navigation réussie).
  void reset() {
    emit(const ConfirmationState.initial());
  }
}
