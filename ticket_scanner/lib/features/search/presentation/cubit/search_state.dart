import '../../domain/entities/medication.dart';
import '../../domain/entities/price_entry.dart';

class SearchState {
  const SearchState({
    required this.query,
    required this.isSearching,
    required this.results,
    required this.medications,
    required this.errorMessage,
  });

  final String query;
  final bool isSearching;

  /// Résultats AVEC prix (priceEntries, issus des tickets).
  final List<PriceEntry> results;

  /// Résultats SANS prix (référentiel ANSM).
  final List<Medication> medications;

  final String? errorMessage;

  const SearchState.initial()
      : query = '',
        isSearching = false,
        results = const [],
        medications = const [],
        errorMessage = null;

  SearchState copyWith({
    String? query,
    bool? isSearching,
    List<PriceEntry>? results,
    List<Medication>? medications,
    String? errorMessage,
  }) {
    return SearchState(
      query: query ?? this.query,
      isSearching: isSearching ?? this.isSearching,
      results: results ?? this.results,
      medications: medications ?? this.medications,
      errorMessage: errorMessage,
    );
  }
}
