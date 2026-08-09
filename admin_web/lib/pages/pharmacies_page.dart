import 'package:flutter/material.dart';

import '../models/pharmacy.dart';
import '../services/firestore_service.dart';

class PharmaciesPage extends StatelessWidget {
  const PharmaciesPage({super.key});

  static const _service = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Pharmacy>>(
      stream: _service.watchPharmacies(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pharmacies = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pharmacies (${pharmacies.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                FilledButton.icon(
                  onPressed: () => _showEditDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (pharmacies.isEmpty)
              const Text('Aucune pharmacie. Ajoute la première.')
            else
              ...pharmacies.map(
                (pharmacy) => _PharmacyTile(
                  pharmacy: pharmacy,
                  onEdit: () => _showEditDialog(context, pharmacy: pharmacy),
                  onDelete: () => _confirmDelete(context, pharmacy),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showEditDialog(
    BuildContext context, {
    Pharmacy? pharmacy,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameController =
        TextEditingController(text: pharmacy?.name ?? '');
    final addressController =
        TextEditingController(text: pharmacy?.address ?? '');
    final communeController =
        TextEditingController(text: pharmacy?.commune ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(pharmacy == null ? 'Ajouter une pharmacie' : 'Modifier'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Nom requis'
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: communeController,
                  decoration: const InputDecoration(
                    labelText: 'Commune / Quartier',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse',
                    border: OutlineInputBorder(),
                  ),
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

    if (saved != true) return;

    final data = Pharmacy(
      id: pharmacy?.id ?? '',
      name: nameController.text.trim(),
      address: addressController.text.trim().isEmpty
          ? null
          : addressController.text.trim(),
      commune: communeController.text.trim().isEmpty
          ? null
          : communeController.text.trim(),
      onDutyDates: pharmacy?.onDutyDates ?? const [],
    );

    if (pharmacy == null) {
      await _service.createPharmacy(data);
    } else {
      await _service.updatePharmacy(data);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Pharmacy pharmacy) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer « ${pharmacy.name} » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deletePharmacy(pharmacy.id);
    }
  }
}

class _PharmacyTile extends StatelessWidget {
  const _PharmacyTile({
    required this.pharmacy,
    required this.onEdit,
    required this.onDelete,
  });

  final Pharmacy pharmacy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (pharmacy.commune != null) pharmacy.commune!,
      if (pharmacy.address != null) pharmacy.address!,
    ];

    return Card(
      child: ListTile(
        leading: const Icon(Icons.local_pharmacy),
        title: Text(pharmacy.name),
        subtitle: Text(
          subtitleParts.isEmpty
              ? (pharmacy.onDutyDates.isEmpty
                  ? 'Aucune date de garde'
                  : 'Garde : ${pharmacy.onDutyDates.length} date(s)')
              : subtitleParts.join(' • '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Dates de garde',
              icon: const Icon(Icons.event_available),
              onPressed: () => _showGardeDialog(context),
            ),
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  void _showGardeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _GardeDialog(pharmacy: pharmacy),
    );
  }
}

class _GardeDialog extends StatefulWidget {
  const _GardeDialog({required this.pharmacy});

  final Pharmacy pharmacy;

  @override
  State<_GardeDialog> createState() => _GardeDialogState();
}

class _GardeDialogState extends State<_GardeDialog> {
  static const _service = FirestoreService();
  late List<String> _dates;
  final TextEditingController _dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dates = List.of(widget.pharmacy.onDutyDates);
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Garde — ${widget.pharmacy.name}'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Dates de garde (yyyy-MM-dd) :'),
            const SizedBox(height: 8),
            Flexible(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final date in _dates)
                    Chip(
                      label: Text(date),
                      onDeleted: () =>
                          setState(() => _dates.remove(date)),
                    ),
                  if (_dates.isEmpty) const Text('Aucune date.'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: 'Ajouter une date (ex: 2026-08-10)',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                final trimmed = value.trim();
                if (trimmed.isEmpty) return;
                setState(() {
                  if (!_dates.contains(trimmed)) _dates.add(trimmed);
                  _dates.sort();
                });
                _dateController.clear();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
        FilledButton(
          onPressed: () async {
            await _service.updatePharmacy(
              widget.pharmacy.copyWith(onDutyDates: _dates),
            );
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
