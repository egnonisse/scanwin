import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'pharmacies_page.dart';
import 'receipts_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _service = FirestoreService();
  int _selectedIndex = 0;

  Future<Map<String, int>> _loadStats() async {
    final pharmacies = await _service.countPharmacies();
    final receipts = await _service.countReceipts();
    final prices = await _service.countPriceEntries();
    return {'pharmacies': pharmacies, 'receipts': receipts, 'prices': prices};
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _StatsView(loadStats: _loadStats),
      const PharmaciesPage(),
      const ReceiptsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmascan Admin'),
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Stats'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_pharmacy_outlined),
                selectedIcon: Icon(Icons.local_pharmacy),
                label: Text('Pharmacies'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: Text('Reçus'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1),
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
    );
  }
}

class _StatsView extends StatelessWidget {
  const _StatsView({required this.loadStats});

  final Future<Map<String, int>> Function() loadStats;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: loadStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final stats = snapshot.data ?? const {};
        return GridView.count(
          padding: const EdgeInsets.all(24),
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _StatCard(
              icon: Icons.local_pharmacy,
              label: 'Pharmacies',
              value: stats['pharmacies'] ?? 0,
            ),
            _StatCard(
              icon: Icons.receipt_long,
              label: 'Reçus soumis',
              value: stats['receipts'] ?? 0,
            ),
            _StatCard(
              icon: Icons.price_check,
              label: 'Prix collectés',
              value: stats['prices'] ?? 0,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
