import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Page « Fusions » — valider ou rejeter les doublons de pharmacies
/// détectés automatiquement (scripts/detect_pharmacy_duplicates.py).
///
/// Fusionner = pointer les doublons vers l'ID canonique (champ mergedInto,
/// NON destructif — les IDs originaux et les reçus restent intacts).
class MergesPage extends StatelessWidget {
  const MergesPage({super.key});

  Future<void> _merge(
      BuildContext context, QueryDocumentSnapshot candidate) async {
    final ids = List<String>.from(
        (candidate.data() as Map?)?['pharmacyIds'] ?? const []);
    if (ids.length < 2) return;

    final canonicalId = ids.first;
    try {
      for (final id in ids.skip(1)) {
        await FirebaseFirestore.instance
            .collection('pharmacies')
            .doc(id)
            .update({'mergedInto': canonicalId});
      }
      await candidate.reference.update({
        'status': 'merged',
        'canonicalId': canonicalId,
        'mergedAt': FieldValue.serverTimestamp(),
      });
      if (!context.mounted) return;
      _snack(context,
          '✅ Fusionné : ${ids.length - 1} entrée(s) → ${ids.first.substring(0, 6)}…');
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, 'Erreur : $e', error: true);
    }
  }

  Future<void> _ignore(
      BuildContext context, QueryDocumentSnapshot candidate) async {
    await candidate.reference.update({
      'status': 'ignored',
      'ignoredAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    _snack(context, 'Candidat ignoré (il ne sera plus proposé).');
  }

  void _snack(BuildContext context, String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Fusions de pharmacies',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Doublons détectés automatiquement (nom + téléphone + commune). '
          'Fusionner = pointer les doublons vers l\'entité canonique '
          '(réversible, non destructif). Relance la détection avec le script '
          'detect_pharmacy_duplicates.py pour rafraîchir la liste.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('mergeCandidates')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Erreur : ${snapshot.error}');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Text('Aucun candidat en attente. 🎉');
            }
            return Column(
              children: [for (final doc in docs) _CandidateCard(
                doc: doc,
                onMerge: () => _merge(context, doc),
                onIgnore: () => _ignore(context, doc),
              )],
            );
          },
        ),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.doc,
    required this.onMerge,
    required this.onIgnore,
  });

  final QueryDocumentSnapshot doc;
  final VoidCallback onMerge;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map? ?? const {};
    final score = data['score']?.toString() ?? 'low';
    final names = List<String>.from(data['names'] ?? const []);
    final communes = List<String>.from(data['communes'] ?? const []);
    final reason = data['reason']?.toString() ?? '';

    final (color, label) = switch (score) {
      'high' => (Colors.green, 'CONFIANCE HAUTE'),
      'medium' => (Colors.orange, 'À VÉRIFIER'),
      _ => (Colors.grey, 'FAIBLE'),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reason,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < names.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${i == 0 ? '★ ' : '• '}${names[i]}'
                  '${communes[i].isNotEmpty ? ' — ${communes[i]}' : ''}',
                  style: i == 0
                      ? const TextStyle(fontWeight: FontWeight.w600)
                      : null,
                ),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onIgnore,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Ignorer'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onMerge,
                  icon: const Icon(Icons.merge, size: 18),
                  label: const Text('Fusionner'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
