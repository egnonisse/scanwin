import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Page Utilisateurs — liste des profils (points, contributions, devise).
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('Aucun utilisateur.'));
        }

        // Stats rapides
        final totalPoints = docs.fold<int>(0, (total, d) {
          final pts = (d.data() as Map?)?['points'] as num?;
          return total + (pts?.toInt() ?? 0);
        });

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Text('Utilisateurs (${docs.length})',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Text('Total points : $totalPoints',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 12),
            ...docs.map((doc) {
              final data = (doc.data() as Map?) ?? const {};
              return _UserTile(doc: doc, data: data);
            }),
          ],
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.doc, required this.data});

  final QueryDocumentSnapshot doc;
  final Map data;

  String _niveau(int points) {
    if (points >= 500) return 'Or';
    if (points >= 200) return 'Argent';
    if (points >= 50) return 'Bronze';
    return 'Contributeur';
  }

  Color _niveauColor(String niveau) {
    switch (niveau) {
      case 'Or':
        return const Color(0xFFD4AF37);
      case 'Argent':
        return const Color(0xFF8E9AAF);
      case 'Bronze':
        return const Color(0xFF9C6B30);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = (data['points'] as num?)?.toInt() ?? 0;
    final contributions = (data['contributions'] as num?)?.toInt() ?? 0;
    final currency = data['currencyCode'] ?? 'XOF';
    final createdAt = data['createdAt'] as Timestamp?;
    final niveau = _niveau(points);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _niveauColor(niveau).withValues(alpha: 0.15),
          child: Icon(Icons.person, color: _niveauColor(niveau)),
        ),
        title: Text(doc.id),
        subtitle: Text(
          [
            'Niveau : $niveau',
            'Contributions : $contributions',
            'Devise : $currency',
            if (createdAt != null)
              'Inscrit : ${createdAt.toDate().toLocal().toString().substring(0, 10)}',
          ].join('  ·  '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$points pts',
                style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              tooltip: 'Corriger les points',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _editPoints(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPoints(BuildContext context) async {
    final controller =
        TextEditingController(text: ((data['points'] as num?)?.toInt() ?? 0).toString());
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Corriger les points'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Points', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (saved == null) return;
    final value = int.tryParse(saved);
    if (value == null) return;
    await doc.reference.update({'points': value});
  }
}
