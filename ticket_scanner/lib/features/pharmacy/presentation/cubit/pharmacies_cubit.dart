import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/repositories/firebase_pharmacy_repository.dart';
import '../../domain/entities/pharmacy.dart';
import '../../domain/repositories/pharmacy_repository.dart';

/// États de la vue pharmacies.
sealed class PharmaciesState {
  const PharmaciesState();
}

class PharmaciesLoading extends PharmaciesState {
  const PharmaciesLoading();
}

class PharmaciesReady extends PharmaciesState {
  const PharmaciesReady({
    required this.pharmacies,
    required this.userLat,
    required this.userLng,
    this.errorMessage,
  });

  final List<Pharmacy> pharmacies;
  final double? userLat;
  final double? userLng;
  final String? errorMessage;

  /// Pharmacies triées par distance croissante (les sans GPS en dernier).
  List<Pharmacy> sortedByDistance() {
    if (userLat == null || userLng == null) {
      return List.of(pharmacies)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    final list = List.of(pharmacies);
    list.sort((a, b) {
      final da = a.distanceKmFrom(userLat!, userLng!);
      final db = b.distanceKmFrom(userLat!, userLng!);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return list;
  }
}

class PharmaciesCubit extends Cubit<PharmaciesState> {
  PharmaciesCubit({PharmacyRepository? repository})
      : _repository = repository ?? const FirebasePharmacyRepository(),
        super(const PharmaciesLoading());

  final PharmacyRepository _repository;
  StreamSubscription<List<Pharmacy>>? _sub;

  /// Demande la permission de localisation (avec dialogue explicatif géré
  /// par la page — conformité stores) puis charge les pharmacies.
  Future<void> start() async {
    double? lat;
    double? lng;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.whileInUse ||
            requested == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 15),
            ),
          );
          lat = pos.latitude;
          lng = pos.longitude;
        }
      } else if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15),
          ),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {
      // Position indisponible : on affiche les pharmacies sans tri distance.
    }

    _sub ??= _repository.watchPharmacies().listen((pharmacies) {
      if (isClosed) return; // navigation pendant le chargement
      emit(PharmaciesReady(
        pharmacies: pharmacies,
        userLat: lat,
        userLng: lng,
      ));
    });
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
