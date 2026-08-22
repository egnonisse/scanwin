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
        // PAS de orderBy ici : where+orderBy sur 2 champs exigerait un
        // index composite (erreur 400 « query requires an index » → le
        // carrousel disparaissait). Tri côté client (2-5 bannières).
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final campaigns = <Campaign>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        // Tolérant aux 2 formats : Timestamp (nouveau dashboard) ou
        // string ISO (anciennes données — causait un cast crash → le
        // carrousel disparaissait silencieusement).
        DateTime? parseDate(Object? value) {
          if (value is Timestamp) return value.toDate();
          if (value is String) {
            final parsed = DateTime.tryParse(value);
            return parsed?.toLocal();
          }
          return null;
        }

        final startDate = parseDate(data['startDate']);
        final endDate = parseDate(data['endDate']);
        // Fenêtre de dates : hors fenêtre = masquée.
        if (startDate != null && now.isBefore(startDate)) continue;
        if (endDate != null && now.isAfter(endDate)) continue;
        campaigns.add(Campaign(
          title: data['title']?.toString() ?? '',
          subtitle: data['subtitle']?.toString(),
          url: data['url']?.toString(),
          backgroundColorHex: data['backgroundColor']?.toString(),
          imageUrl: data['imageUrl']?.toString(),
          sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
        ));
      }
      final result = campaigns.where((c) => c.title.isNotEmpty).toList()
        // Tri côté client (pas d'orderBy Firestore : évite l'index
        // composite requis).
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return result;
    });
  }
}
