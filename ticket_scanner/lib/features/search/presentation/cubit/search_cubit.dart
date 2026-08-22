import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/medication.dart';
import '../../domain/entities/price_entry.dart';
import '../../domain/repositories/medication_repository.dart';
import '../../domain/repositories/price_repository.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit({
    required PriceRepository repository,
    required MedicationRepository medicationRepository,
  })  : _repository = repository,
        _medicationRepository = medicationRepository,
        super(const SearchState.initial());

  final PriceRepository _repository;
  final MedicationRepository _medicationRepository;

  StreamSubscription<List<PriceEntry>>? _priceSub;
  StreamSubscription<List<Medication>>? _medSub;

  /// Lance une recherche dans LES DEUX sources en parallèle :
  /// - priceEntries (médicaments AVEC prix issus des tickets)
  /// - medications (référentiel ANSM, sans prix)
  void search(String query) {
    _priceSub?.cancel();
    _medSub?.cancel();

    final trimmed = query.trim();
    if (trimmed.length < 3) {
      emit(const SearchState.initial());
      return;
    }

    emit(
      state.copyWith(
        query: trimmed,
        isSearching: true,
        errorMessage: null,
      ),
    );

    _priceSub = _repository.searchByMedication(trimmed).listen(
      (results) {
        if (isClosed) return;
        emit(state.copyWith(isSearching: false, results: results));
      },
      onError: (_) => _emitError(),
    );

    _medSub = _medicationRepository.searchByName(trimmed).listen(
      (medications) {
        if (isClosed) return;
        emit(state.copyWith(isSearching: false, medications: medications));
      },
      onError: (_) => _emitError(),
    );
  }

  void _emitError() {
    if (isClosed) return;
    emit(
      state.copyWith(
        isSearching: false,
        errorMessage: 'Recherche impossible. Vérifie ta connexion.',
      ),
    );
  }

  @override
  Future<void> close() async {
    await _priceSub?.cancel();
    await _medSub?.cancel();
    return super.close();
  }
}
