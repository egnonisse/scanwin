class SettingsState {
  const SettingsState({
    required this.currencyCode,
    required this.isLoading,
    required this.errorMessage,
  });

  final String currencyCode;
  final bool isLoading;
  final String? errorMessage;

  SettingsState copyWith({
    String? currencyCode,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SettingsState(
      currencyCode: currencyCode ?? this.currencyCode,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

