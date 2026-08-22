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
    final users = await db.collection('users').limit(500).get();
    final prices = await db.collection('priceEntries').limit(500).get();
    final receipts = await db.collection('receipts').limit(500).get();
    final pharmacies = await db.collection('pharmacies').limit(500).get();

    // Pharmacies de garde aujourd'hui
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

    // Prix moyen + top médicaments
    double priceSum = 0;
    int priceCount = 0;
    final medCount = <String, int>{};
    for (final p in prices.docs) {
      final price = p.data()['price'] as num?;
      if (price != null) {
        priceSum += price.toDouble();
        priceCount++;
      }
      final name = p.data()['medicationName']?.toString() ?? '?';
      medCount[name] = (medCount[name] ?? 0) + 1;
    }
    final topMeds = medCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'users': users.docs.length,
      'totalPoints': totalPoints,
      'prices': priceCount,
      'priceAvg': priceCount > 0 ? priceSum / priceCount : 0,
      'receipts': receipts.docs.length,
      'pharmacies': pharmacies.docs.length,
      'onDuty': onDuty,
      'topMeds': topMeds.take(10).toList(),
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
                _StatCard(label: 'Prix en base', value: '${s['prices'] ?? 0}'),
                _StatCard(
                    label: 'Prix moyen',
                    value:
                        '${(s['priceAvg'] as num? ?? 0).toStringAsFixed(0)} F'),
                _StatCard(label: 'Tickets scannés', value: '${s['receipts'] ?? 0}'),
                _StatCard(
                    label: 'Pharmacies de garde (aujourd\'hui)',
                    value: '${s['onDuty'] ?? 0}'),
              ],
            ),
            const SizedBox(height: 24),
            Text('Top médicaments en base',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...((s['topMeds'] as List? ?? []).isEmpty
                ? [const Text('Aucun médicament en base.')]
                : (s['topMeds'] as List).map((e) {
                    return Card(
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.medication,
                            color: Theme.of(context).colorScheme.primary),
                        title: Text('${e.key}'),
                        trailing: Text('${e.value} prix'),
                      ),
                    );
                  })),
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
