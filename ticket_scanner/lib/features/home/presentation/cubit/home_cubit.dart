import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/contributor_profile.dart';
import '../../domain/repositories/home_repository.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({required HomeRepository repository})
      : _repository = repository,
        super(const HomeState.initial());

  final HomeRepository _repository;

  StreamSubscription<ContributorProfile>? _profileSub;
  StreamSubscription? _eventsSub;

  void start() {
    emit(state.copyWith(isLoading: true, errorMessage: null));

    _profileSub?.cancel();
    _eventsSub?.cancel();

    _profileSub = _repository.watchProfile().listen(
      (profile) {
        if (isClosed) return;
        emit(state.copyWith(profile: profile, isLoading: false));
      },
      onError: (_) {
        if (isClosed) return;
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: 'Impossible de charger ton profil.',
          ),
        );
      },
    );

    _eventsSub = _repository.watchLatestEvents().listen(
      (events) {
        if (isClosed) return;
        emit(state.copyWith(events: events, isLoading: false));
      },
      onError: (_) {
        if (isClosed) return;
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: 'Impossible de charger l’historique.',
          ),
        );
      },
    );
  }

  @override
  Future<void> close() async {
    await _profileSub?.cancel();
    await _eventsSub?.cancel();
    return super.close();
  }
}
