import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Page Analytics — indicateurs clés de l'app (données Firestore temps réel)
/// + lien vers la console Firebase Analytics (événements détaillés).
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  Future<Map<String, dynamic>> _loadStats() async {
    final db = FirebaseFirestore.instance;
    // Compteurs EXACTS (maintenus par scripts/refresh_stats.py — les
    // queries client limit(500) étaient fausses avec 53k produits).
    final globalDoc = await db.collection('stats').doc('global').get();
    final global = globalDoc.data() ?? <String, dynamic>{};
    // Collections vivantes (petites : < 500 docs).
    final users = await db.collection('users').limit(500).get();
    final receipts = await db.collection('receipts').limit(500).get();
    final pharmacies = await db.collection('pharmacies').limit(500).get();
    final config = await db.collection('contentConfig').doc('default').get();
    final configData = config.data() ?? <String, dynamic>{};

    final today = DateTime.now();
    final todayIso =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final onDuty = pharmacies.docs
        .where((d) =>
            ((d.data()['onDutyDates'] as List?) ?? []).contains(todayIso))
        .length;

    final totalPoints = users.docs.fold<int>(0, (total, d) {
      final pts = (d.data()['points'] as num?);
      return total + (pts?.toInt() ?? 0);
    });

    return {
      'users': users.docs.length,
      'totalPoints': totalPoints,
      'receipts': receipts.docs.length,
      'pharmacies': global['pharmacies'] ?? pharmacies.docs.length,
      'onDuty': onDuty,
      'prices': global['priceEntries'] ?? 0,
      'pricesOfficial': global['priceEntriesOfficial'] ?? 0,
      'medications': global['medications'] ?? 0,
      'catalogProducts': global['catalogProducts'] ?? 0,
      'catalogInStock': global['catalogInStock'] ?? 0,
      'referralsActivated': global['referralsActivated'] ?? 0,
      'hiddenMeds': ((configData['hiddenMedications'] as List?) ?? []).length,
      'disabledCats':
          ((configData['disabledCategories'] as List?) ?? []).length,
      'mergeCandidates': global['mergeCandidates'] ?? 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final s = snapshot.data ?? const {};
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Text('Analytics', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse(
                      'https://console.firebase.google.com/project/boostsocial-a7720/analytics/overview')),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Console Firebase Analytics'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Les événements détaillés (scans, recherches, rétention) sont dans '
              'Firebase Analytics. Ici : les données métier en temps réel.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _StatCard(label: 'Utilisateurs', value: '${s['users'] ?? 0}'),
                _StatCard(
                    label: 'Total points', value: '${s['totalPoints'] ?? 0}'),
                _StatCard(
                    label: 'Tickets scannés', value: '${s['receipts'] ?? 0}'),
                _StatCard(
                    label: 'Pharmacies', value: '${s['pharmacies'] ?? 0}'),
                _StatCard(
                    label: 'Pharmacies de garde (aujourd\'hui)',
                    value: '${s['onDuty'] ?? 0}'),
                _StatCard(
                    label: 'Prix médicaments (total)',
                    value: '${s['prices'] ?? 0}'),
                _StatCard(
                    label: 'dont prix officiels',
                    value: '${s['pricesOfficial'] ?? 0}'),
                _StatCard(
                    label: 'Médicaments ANSM',
                    value: '${s['medications'] ?? 0}'),
                _StatCard(
                    label: 'Parapharmacie',
                    value: '${s['catalogProducts'] ?? 0}'),
                _StatCard(
                    label: 'dont en stock',
                    value: '${s['catalogInStock'] ?? 0}'),
                _StatCard(
                    label: 'Médicaments masqués',
                    value: '${s['hiddenMeds'] ?? 0}'),
                _StatCard(
                    label: 'Catégories désactivées',
                    value: '${s['disabledCats'] ?? 0}'),
                _StatCard(
                    label: 'Filleuls parrainés (1er scan)',
                    value: '${s['referralsActivated'] ?? 0}'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Compteurs rafraîchis par scripts/refresh_stats.py '
                    '(count exact, pas d\'échantillon limit(500)).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    )),
            const SizedBox(height: 4),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
