import '../../domain/entities/price_entry.dart';

class SearchState {
  const SearchState({
    required this.query,
    required this.isSearching,
    required this.results,
    required this.errorMessage,
  });

  final String query;
  final bool isSearching;
  final List<PriceEntry> results;
  final String? errorMessage;

  const SearchState.initial()
      : query = '',
        isSearching = false,
        results = const [],
        errorMessage = null;

  SearchState copyWith({
    String? query,
    bool? isSearching,
    List<PriceEntry>? results,
    String? errorMessage,
  }) {
    return SearchState(
      query: query ?? this.query,
      isSearching: isSearching ?? this.isSearching,
      results: results ?? this.results,
      errorMessage: errorMessage,
    );
  }
}
