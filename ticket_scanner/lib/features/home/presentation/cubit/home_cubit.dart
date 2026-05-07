import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/home_repository.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({required HomeRepository repository})
      : _repository = repository,
        super(const HomeState.initial());

  final HomeRepository _repository;

  StreamSubscription<int>? _pointsSub;
  StreamSubscription? _eventsSub;

  void start() {
    emit(state.copyWith(isLoading: true, errorMessage: null));

    _pointsSub?.cancel();
    _eventsSub?.cancel();

    _pointsSub = _repository.watchPoints().listen(
      (points) => emit(state.copyWith(points: points, isLoading: false)),
      onError: (_) => emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Impossible de charger les points.',
        ),
      ),
    );

    _eventsSub = _repository.watchLatestEvents().listen(
      (events) => emit(state.copyWith(events: events, isLoading: false)),
      onError: (_) => emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Impossible de charger l’historique.',
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _pointsSub?.cancel();
    await _eventsSub?.cancel();
    return super.close();
  }
}

