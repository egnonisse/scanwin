import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/medication.dart';

/// Un prix affiché sur la fiche (officiel ou scanné).
class MedicationPriceInfo {
  const MedicationPriceInfo({
    required this.pharmacyId,
    required this.pharmacyName,
    required this.price,
    this.scannedAt,
    this.therapeuticGroup,
    this.code,
    this.isOfficial = false,
  });

  final String pharmacyId;
  final String pharmacyName;
  final double price;
  final DateTime? scannedAt;
  final String? therapeuticGroup;
  final String? code;

  /// true = prix public officiel (référence, pas une pharmacie physique).
  final bool isOfficial;
}

/// États de la fiche médicament.
sealed class MedicationDetailState {
  const MedicationDetailState();
}

class MedicationDetailLoading extends MedicationDetailState {
  const MedicationDetailLoading();
}

class MedicationDetailReady extends MedicationDetailState {
  const MedicationDetailReady({
    required this.displayName,
    required this.prices,
    required this.medication,
    this.ansmStatus,
  });

  final String displayName;
  final List<MedicationPriceInfo> prices;
  final Medication? medication;

  /// Statut AMM (« Commercialisée »…) si trouvé.
  final String? ansmStatus;
}

class MedicationDetailError extends MedicationDetailState {
  const MedicationDetailError(this.message);

  final String message;
}

/// Charge la fiche d'un médicament : prix (priceEntries) + fiche ANSM.
class MedicationDetailCubit extends Cubit<MedicationDetailState> {
  MedicationDetailCubit({
    required this.normalizedName,
    required this.displayName,
  }) : super(const MedicationDetailLoading());

  final String normalizedName;
  final String displayName;

  static const _officialId = 'public-price-ci';

  Future<void> load() async {
    try {
      final pricesFuture = FirebaseFirestore.instance
          .collection('priceEntries')
          .where('medicationName', isEqualTo: normalizedName)
          .get();
      // Match ANSM : préfixe sur le premier mot significatif (ex :
      // « DOLIPRANE » — les noms ANSM et commerciaux diffèrent toujours).
      final prefix = normalizedName.split(' ').first.toUpperCase();
      final ansmFuture = FirebaseFirestore.instance
          .collection('medications')
          .where('name', isGreaterThanOrEqualTo: prefix)
          .where('name', isLessThanOrEqualTo: '$prefix\uf8ff')
          .limit(5)
          .get();

      final results = await Future.wait([pricesFuture, ansmFuture]);
      final priceSnap = results[0];
      final ansmSnap = results[1];

      final prices = <MedicationPriceInfo>[];
      String? effectiveDisplayName;
      for (final doc in priceSnap.docs) {
        final data = doc.data();
        effectiveDisplayName ??= data['displayName'] as String?;
        final pharmacyId = data['pharmacyId'] as String? ?? '';
        prices.add(MedicationPriceInfo(
          pharmacyId: pharmacyId,
          pharmacyName: data['pharmacyName'] as String? ??
              data['displayName'] as String? ??
              pharmacyId,
          price: (data['price'] as num?)?.toDouble() ?? 0,
          scannedAt: (data['scannedAt'] as Timestamp?)?.toDate(),
          therapeuticGroup: data['therapeuticGroup'] as String?,
          code: data['code'] as String?,
          isOfficial: pharmacyId == _officialId,
        ));
      }
      prices.sort((a, b) => a.price.compareTo(b.price));

      Medication? medication;
      String? ansmStatus;
      if (ansmSnap.docs.isNotEmpty) {
        final data = ansmSnap.docs.first.data();
        medication = Medication(
          name: data['name']?.toString() ?? '',
          form: data['form']?.toString(),
          routes: data['routes']?.toString(),
          titulaire: data['titulaire']?.toString(),
          dcis: (data['dcis'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
        );
        ansmStatus = data['status']?.toString();
      }

      emit(MedicationDetailReady(
        displayName: effectiveDisplayName ?? displayName,
        prices: prices,
        medication: medication,
        ansmStatus: ansmStatus,
      ));
    } catch (_) {
      emit(const MedicationDetailError('Impossible de charger la fiche.'));
    }
  }
}
