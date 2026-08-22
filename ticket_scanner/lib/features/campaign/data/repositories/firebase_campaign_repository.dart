import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/campaign.dart';

/// Repository Firestore des campagnes (bannières home).
///
/// Filtre serveur/côté client : uniquement les campagnes `active == true`
/// et dans leur fenêtre de dates (startDate ≤ aujourd'hui ≤ endDate).
class FirebaseCampaignRepository {
  const FirebaseCampaignRepository();

  Stream<List<Campaign>> watchActiveCampaigns() {
    return FirebaseFirestore.instance
        .collection('campaigns')
        .where('active', isEqualTo: true)
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final campaigns = <Campaign>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final startDate = (data['startDate'] as Timestamp?)?.toDate();
        final endDate = (data['endDate'] as Timestamp?)?.toDate();
        // Fenêtre de dates : hors fenêtre = masquée.
        if (startDate != null && now.isBefore(startDate)) continue;
        if (endDate != null && now.isAfter(endDate)) continue;
        campaigns.add(Campaign(
          title: data['title']?.toString() ?? '',
          subtitle: data['subtitle']?.toString(),
          url: data['url']?.toString(),
          backgroundColorHex: data['backgroundColor']?.toString(),
        ));
      }
      return campaigns.where((c) => c.title.isNotEmpty).toList();
    });
  }
}
