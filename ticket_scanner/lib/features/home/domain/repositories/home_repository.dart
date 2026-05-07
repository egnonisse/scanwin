import '../entities/points_event.dart';

abstract class HomeRepository {
  Stream<int> watchPoints();
  Stream<List<PointsEvent>> watchLatestEvents({int limit = 20});
}

