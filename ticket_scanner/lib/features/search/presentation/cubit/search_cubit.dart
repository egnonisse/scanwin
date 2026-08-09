import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/price_entry.dart';
import '../../domain/repositories/price_repository.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit({required PriceRepository repository})
      : _repository = repository,
        super(const SearchState.initial());

  final PriceRepository _repository;
  StreamSubscription<List<PriceEntry>>? _subscription;

  /// Lance une recherche (3 caractères minimum).
  void search(String query) {
    _subscription?.cancel();

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

    _subscription = _repository.searchByMedication(trimmed).listen(
      (results) => emit(
        state.copyWith(isSearching: false, results: results),
      ),
      onError: (_) => emit(
        state.copyWith(
          isSearching: false,
          errorMessage: 'Recherche impossible. Vérifie ta connexion.',
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
