import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/contributor_profile.dart';
import '../../domain/entities/points_event.dart';
import '../../domain/repositories/home_repository.dart';
import '../models/points_event_model.dart';

class FirebaseHomeRepository implements HomeRepository {
  FirebaseHomeRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _auth = auth,
        _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Utilisateur non authentifié.');
    return uid;
  }

  @override
  Stream<ContributorProfile> watchProfile() {
    final ref = _firestore.collection('users').doc(_uid);
    return ref.snapshots().map((doc) {
      final data = doc.data() ?? <String, dynamic>{};
      return ContributorProfile(
        points: (data['points'] as num?)?.toInt() ?? 0,
        contributions: (data['contributions'] as num?)?.toInt() ?? 0,
      );
    });
  }

  @override
  Stream<List<PointsEvent>> watchLatestEvents({int limit = 20}) {
    final ref = _firestore
        .collection('users')
        .doc(_uid)
        .collection('pointsEvents')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    return ref.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => PointsEventModel.fromDoc(doc).toEntity())
              .toList(growable: false),
        );
  }
}
