import '../../domain/entities/contributor_profile.dart';
import '../../domain/entities/points_event.dart';

class HomeState {
  const HomeState({
    required this.profile,
    required this.events,
    required this.isLoading,
    required this.errorMessage,
  });

  final ContributorProfile profile;
  final List<PointsEvent> events;
  final bool isLoading;
  final String? errorMessage;

  const HomeState.initial()
      : profile = const ContributorProfile(points: 0, contributions: 0),
        events = const [],
        isLoading = true,
        errorMessage = null;

  HomeState copyWith({
    ContributorProfile? profile,
    List<PointsEvent>? events,
    bool? isLoading,
    String? errorMessage,
  }) {
    return HomeState(
      profile: profile ?? this.profile,
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}
