import '../entities/contributor_profile.dart';
import '../entities/points_event.dart';

abstract class HomeRepository {
  /// Profil contributeur (points + reçus validés), en temps réel.
  Stream<ContributorProfile> watchProfile();

  Stream<List<PointsEvent>> watchLatestEvents({int limit = 20});
}
