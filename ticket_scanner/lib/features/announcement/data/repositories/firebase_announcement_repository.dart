import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/announcement.dart';

/// Repository Firestore des annonces (popups in-app).
///
/// Filtre : actives + dans leur fenêtre de dates ; triées par date de
/// création décroissante (la plus récente en premier).
class FirebaseAnnouncementRepository {
  const FirebaseAnnouncementRepository();

  Stream<List<Announcement>> watchActiveAnnouncements() {
    return FirebaseFirestore.instance
        .collection('announcements')
        .where('active', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final announcements = <Announcement>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final startDate = (data['startDate'] as Timestamp?)?.toDate();
        final endDate = (data['endDate'] as Timestamp?)?.toDate();
        if (startDate != null && now.isBefore(startDate)) continue;
        if (endDate != null && now.isAfter(endDate)) continue;
        announcements.add(Announcement(
          id: doc.id,
          title: data['title']?.toString() ?? '',
          message: data['message']?.toString() ?? '',
          type: data['type']?.toString() ?? 'info',
          ctaLabel: data['ctaLabel']?.toString(),
          ctaUrl: data['ctaUrl']?.toString(),
          imageUrl: data['imageUrl']?.toString(),
          oncePerUser: data['oncePerUser'] as bool? ?? true,
        ));
      }
      return announcements
          .where((a) => a.title.isNotEmpty && a.message.isNotEmpty)
          .toList();
    });
  }
}
