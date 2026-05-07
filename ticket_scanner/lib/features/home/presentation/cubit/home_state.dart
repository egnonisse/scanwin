import '../../domain/entities/points_event.dart';

class HomeState {
  const HomeState({
    required this.points,
    required this.events,
    required this.isLoading,
    required this.errorMessage,
  });

  final int points;
  final List<PointsEvent> events;
  final bool isLoading;
  final String? errorMessage;

  const HomeState.initial()
      : points = 0,
        events = const [],
        isLoading = true,
        errorMessage = null;

  HomeState copyWith({
    int? points,
    List<PointsEvent>? events,
    bool? isLoading,
    String? errorMessage,
  }) {
    return HomeState(
      points: points ?? this.points,
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

