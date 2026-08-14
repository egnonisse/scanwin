import '../../domain/entities/receipt_extraction.dart';

class ScannerState {
  const ScannerState({
    required this.isLoading,
    required this.extraction,
    required this.errorMessage,
    this.imagePath,
  });

  final bool isLoading;
  final ReceiptExtraction? extraction;
  final String? errorMessage;

  /// Chemin du fichier image prétraité (photo du reçu, pour l'archivage).
  final String? imagePath;

  const ScannerState.initial()
      : isLoading = false,
        extraction = null,
        errorMessage = null,
        imagePath = null;

  ScannerState copyWith({
    bool? isLoading,
    ReceiptExtraction? extraction,
    String? errorMessage,
    String? imagePath,
  }) {
    return ScannerState(
      isLoading: isLoading ?? this.isLoading,
      extraction: extraction ?? this.extraction,
      errorMessage: errorMessage,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
