enum AppInitStatus { initial, loading, ready, error }

class AppInitState {
  const AppInitState({
    required this.status,
    required this.errorMessage,
  });

  final AppInitStatus status;
  final String? errorMessage;

  const AppInitState.initial()
      : status = AppInitStatus.initial,
        errorMessage = null;

  AppInitState copyWith({
    AppInitStatus? status,
    String? errorMessage,
  }) {
    return AppInitState(
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

