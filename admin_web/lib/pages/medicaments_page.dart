import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Page Médicaments — gestion complète du contenu :
/// - Onglet Prix : CRUD des prix + VISIBILITÉ par médicament (œil)
/// - Onglet Catégories : activer/désactiver des groupes thérapeutiques
/// - Bandeau de statistiques (total, masqués, catégories désactivées)
///
/// La visibilité est stockée dans contentConfig/default :
/// hiddenMedications[] + disabledCategories[] — l'app filtre à la lecture.
class MedicamentsPage extends StatefulWidget {
  const MedicamentsPage({super.key});

  @override
  State<MedicamentsPage> createState() => _MedicamentsPageState();
}

class _MedicamentsPageState extends State<MedicamentsPage> {
  static const _limit = 100;
  final _searchController = TextEditingController();
  String _query = '';
  int _tabIndex = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Query _baseQuery() {
    return FirebaseFirestore.instance
        .collection('priceEntries')
        .orderBy('scannedAt', descending: true);
  }

  Future<void> _toggleHidden(String medicationName, bool hide) async {
    final ref =
        FirebaseFirestore.instance.collection('contentConfig').doc('default');
    if (hide) {
      await ref.set({
        'hiddenMedications': FieldValue.arrayUnion([medicationName]),
      }, SetOptions(merge: true));
    } else {
      await ref.update({
        'hiddenMedications': FieldValue.arrayRemove([medicationName]),
      });
    }
  }

  Future<void> _toggleCategory(String category, bool disable) async {
    final ref =
        FirebaseFirestore.instance.collection('contentConfig').doc('default');
    if (disable) {
      await ref.set({
        'disabledCategories': FieldValue.arrayUnion([category]),
      }, SetOptions(merge: true));
    } else {
      await ref.update({
        'disabledCategories': FieldValue.arrayRemove([category]),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _StatsBanner(onRefresh: () => setState(() {})),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.sell),
                label: Text('Prix'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.category),
                label: Text('Catégories'),
              ),
            ],
            selected: {_tabIndex},
            onSelectionChanged: (s) => setState(() => _tabIndex = s.first),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _tabIndex == 0 ? _buildPricesTab() : _buildCategoriesTab(),
        ),
      ],
    );
  }

  Widget _buildPricesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Filtrer par médicament (ex : paracétamol)…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _showEditDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un prix'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _query.isEmpty
              ? _PrixList(
                  query: _baseQuery().limit(_limit),
                  onToggleHidden: _toggleHidden,
                  onEdit: (doc) => _showEditDialog(context, doc: doc),
                  onDelete: (doc) => _confirmDelete(context, doc),
                )
              : _PrixList(
                  query: FirebaseFirestore.instance
                      .collection('priceEntries')
                      .where('medicationName',
                          isGreaterThanOrEqualTo: _query)
                      .where('medicationName',
                          isLessThanOrEqualTo: '$_query\uf8ff')
                      .limit(_limit),
                  onToggleHidden: _toggleHidden,
                  onEdit: (doc) => _showEditDialog(context, doc: doc),
                  onDelete: (doc) => _confirmDelete(context, doc),
                ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('contentConfig')
          .doc('default')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final categories =
            (data['categories'] as List?)?.map((e) => e.toString()).toList() ??
                [];
        final disabled = ((data['disabledCategories'] as List?)
                ?.map((e) => e.toString())
                .toSet() ??
            <String>{});
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              '${categories.length} groupes thérapeutiques — désactive une '
              'catégorie pour la masquer de l\'app.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final cat in categories)
              Card(
                child: ListTile(
                  dense: true,
                  title: Text(cat),
                  trailing: Switch(
                    value: !disabled.contains(cat),
                    onChanged: (active) => _toggleCategory(cat, !active),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showEditDialog(BuildContext context,
      {QueryDocumentSnapshot? doc}) async {
    final medController =
        TextEditingController(text: doc?['medicationName'] ?? '');
    final pharmController =
        TextEditingController(text: doc?['pharmacyName'] ?? '');
    final priceController = TextEditingController(
        text: doc?['price']?.toString() ?? '');
    final qtyController =
        TextEditingController(text: doc?['quantity']?.toString() ?? '1');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(doc == null ? 'Ajouter un prix' : 'Modifier le prix'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: medController,
                decoration: const InputDecoration(
                    labelText: 'Médicament', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: pharmController,
                decoration: const InputDecoration(
                    labelText: 'Pharmacie', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(
                    labelText: 'Prix (FCFA)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    double.tryParse(v?.replaceAll(',', '.') ?? '') == null
                        ? 'Nombre requis'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyController,
                decoration: const InputDecoration(
                    labelText: 'Quantité', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;

    final payload = {
      'medicationName': medController.text.trim(),
      'pharmacyName': pharmController.text.trim(),
      'price': double.parse(priceController.text.replaceAll(',', '.')),
      'quantity': int.tryParse(qtyController.text) ?? 1,
    };

    if (doc == null) {
      await FirebaseFirestore.instance.collection('priceEntries').add({
        ...payload,
        'scannedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await doc.reference.update(payload);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, QueryDocumentSnapshot doc) async {
    final medName =
        (doc.data() as Map<String, dynamic>?)?['medicationName'] ?? '?';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce prix ?'),
        content: Text('« $medName » sera retiré de la table de recherche.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await doc.reference.delete();
    }
  }
}

/// Bandeau de statistiques : total prix, masqués, catégories désactivées.
class _StatsBanner extends StatelessWidget {
  const _StatsBanner({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FirebaseFirestore.instance
          .collection('contentConfig')
          .doc('default')
          .get(),
      builder: (context, configSnap) {
        final config = configSnap.data?.data() ?? <String, dynamic>{};
        final hidden = ((config['hiddenMedications'] as List?) ?? []).length;
        final disabled =
            ((config['disabledCategories'] as List?) ?? []).length;
        final categories = ((config['categories'] as List?) ?? []).length;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(label: 'Catégories', value: '$categories'),
                _Stat(label: 'Catégories masquées', value: '$disabled'),
                _Stat(label: 'Médicaments masqués', value: '$hidden'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Liste des prix avec actions : éditer, supprimer, VISIBILITÉ (œil).
class _PrixList extends StatelessWidget {
  const _PrixList({
    required this.query,
    required this.onToggleHidden,
    required this.onEdit,
    required this.onDelete,
  });

  final Query query;
  final Future<void> Function(String medicationName, bool hide) onToggleHidden;
  final void Function(QueryDocumentSnapshot doc) onEdit;
  final void Function(QueryDocumentSnapshot doc) onDelete;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text('Erreur : ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('Aucun prix trouvé.'));
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final medName = data['medicationName'] ?? '?';
            return FutureBuilder<Map<String, dynamic>>(
              future: FirebaseFirestore.instance
                  .collection('contentConfig')
                  .doc('default')
                  .get()
                  .then((d) => d.data() ?? <String, dynamic>{}),
              builder: (context, configSnap) {
                final config = configSnap.data ?? <String, dynamic>{};
                final hidden = ((config['hiddenMedications'] as List?) ?? [])
                    .contains(medName);
                return ListTile(
                  dense: true,
                  title: Text(medName, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${data['pharmacyName'] ?? '?'} — '
                    '${(data['price'] as num?)?.toStringAsFixed(0) ?? '?'} F'
                    '${hidden ? ' · MASQUÉ' : ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          hidden ? Icons.visibility_off : Icons.visibility,
                          color: hidden ? Colors.red : null,
                        ),
                        tooltip:
                            hidden ? 'Rendre visible' : 'Masquer de l\'app',
                        onPressed: () => onToggleHidden(medName, !hidden),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Modifier',
                        onPressed: () => onEdit(doc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Supprimer',
                        onPressed: () => onDelete(doc),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
