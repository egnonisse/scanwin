enum ConfirmationStatus { initial, submitting, success, error }

class ConfirmationState {
  const ConfirmationState({
    required this.status,
    required this.pointsAdded,
    required this.errorMessage,
  });

  final ConfirmationStatus status;
  final int pointsAdded;
  final String? errorMessage;

  const ConfirmationState.initial()
      : status = ConfirmationStatus.initial,
        pointsAdded = 0,
        errorMessage = null;

  ConfirmationState copyWith({
    ConfirmationStatus? status,
    int? pointsAdded,
    String? errorMessage,
  }) {
    return ConfirmationState(
      status: status ?? this.status,
      pointsAdded: pointsAdded ?? this.pointsAdded,
      errorMessage: errorMessage,
    );
  }
}
