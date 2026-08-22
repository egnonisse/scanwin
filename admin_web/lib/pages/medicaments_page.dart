import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Page Médicaments — CRUD de la table des prix (priceEntries).
/// Champs : medicationName, pharmacyName, price, quantity, scannedAt.
class MedicamentsPage extends StatefulWidget {
  const MedicamentsPage({super.key});

  @override
  State<MedicamentsPage> createState() => _MedicamentsPageState();
}

class _MedicamentsPageState extends State<MedicamentsPage> {
  static const _limit = 100;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Query _baseQuery() {
    var q = FirebaseFirestore.instance
        .collection('priceEntries')
        .orderBy('scannedAt', descending: true);
    return q;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
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
              ? _PrixList(query: _baseQuery().limit(_limit))
              : _PrixList(
                  query: FirebaseFirestore.instance
                      .collection('priceEntries')
                      .where('medicationName',
                          isGreaterThanOrEqualTo: _query)
                      .where('medicationName',
                          isLessThanOrEqualTo: '$_query\uf8ff')
                      .limit(_limit),
                ),
        ),
      ],
    );
  }

  Future<void> _showEditDialog(BuildContext context,
      {QueryDocumentSnapshot? doc}) async {
    final formKey = GlobalKey<FormState>();
    final data = doc?.data() as Map<String, dynamic>? ?? const {};
    final medController = TextEditingController(
        text: data['medicationName'] as String? ?? '');
    final pharmController = TextEditingController(
        text: data['pharmacyName'] as String? ?? '');
    final priceController = TextEditingController(
        text: (data['price'] as num?)?.toString() ?? '');
    final qtyController = TextEditingController(
        text: (data['quantity'] as num?)?.toString() ?? '1');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(doc == null ? 'Ajouter un prix' : 'Modifier le prix'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
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

class _PrixList extends StatelessWidget {
  const _PrixList({required this.query});

  final Query query;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
              child: Text('Aucun prix en base. Scannez des tickets ou ajoutez manuellement.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data()! as Map<String, dynamic>;
            final price = data['price'];
            final qty = data['quantity'];
            return Card(
              child: ListTile(
                leading: Icon(Icons.medication,
                    color: Theme.of(context).colorScheme.primary),
                title: Text(data['medicationName']?.toString() ?? '?'),
                subtitle: Text(
                  '${data['pharmacyName'] ?? '?'}'
                  '${qty != null ? ' · qty $qty' : ''}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      price is num
                          ? '${price.toStringAsFixed(0)} F'
                          : '?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      tooltip: 'Modifier',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () {
                        final state = context
                            .findAncestorStateOfType<_MedicamentsPageState>();
                        state?._showEditDialog(context, doc: doc);
                      },
                    ),
                    IconButton(
                      tooltip: 'Supprimer',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () {
                        final state = context
                            .findAncestorStateOfType<_MedicamentsPageState>();
                        state?._confirmDelete(context, doc);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
