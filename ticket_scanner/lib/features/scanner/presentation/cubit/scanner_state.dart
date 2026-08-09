import '../../domain/entities/receipt_extraction.dart';

class ScannerState {
  const ScannerState({
    required this.isLoading,
    required this.extraction,
    required this.errorMessage,
  });

  final bool isLoading;
  final ReceiptExtraction? extraction;
  final String? errorMessage;

  const ScannerState.initial()
      : isLoading = false,
        extraction = null,
        errorMessage = null;

  ScannerState copyWith({
    bool? isLoading,
    ReceiptExtraction? extraction,
    String? errorMessage,
  }) {
    return ScannerState(
      isLoading: isLoading ?? this.isLoading,
      extraction: extraction ?? this.extraction,
      errorMessage: errorMessage,
    );
  }
}
