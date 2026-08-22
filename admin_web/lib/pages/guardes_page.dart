import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

import '../models/pharmacy.dart';
import '../services/firestore_service.dart';

/// Page Gardes — CRUD des dates de garde des pharmacies + import JSON (scraper).
class GuardesPage extends StatefulWidget {
  const GuardesPage({super.key});

  @override
  State<GuardesPage> createState() => _GuardesPageState();
}

class _GuardesPageState extends State<GuardesPage> {
  static const _service = FirestoreService();
  DateTime _filterDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final todayIso = _iso(_filterDate);
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
        final onDutyToday = pharmacies
            .where((p) => p.onDutyDates.contains(todayIso))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Text('Gardes du jour',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                _DatePickerChip(
                  date: _filterDate,
                  onChanged: (d) => setState(() => _filterDate = d),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showImportDialog(context),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Importer JSON'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${onDutyToday.length} pharmacie(s) de garde le '
              '${_formatFr(_filterDate)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            if (onDutyToday.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Aucune pharmacie de garde ce jour.')),
              )
            else
              ...onDutyToday.map(
                (p) => _GardeTile(
                  pharmacy: p,
                  date: todayIso,
                  onAddDate: () => _editDates(context, p),
                  onRemoveDate: () => _removeDate(context, p, todayIso),
                ),
              ),
          ],
        );
      },
    );
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _formatFr(DateTime d) =>
      '${d.day}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Ajoute des dates de garde à une pharmacie (multi-sélection de jours).
  Future<void> _editDates(BuildContext context, Pharmacy pharmacy) async {
    final startDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      initialDate: _filterDate,
    );
    if (startDate == null || !mounted) return;

    if (!context.mounted) return;
    final nbDays = await _askNbDays(context);
    if (nbDays == null || !mounted) return;

    final newDates = [
      for (var i = 0; i < nbDays; i++)
        _iso(startDate.add(Duration(days: i))),
    ];
    final merged = {...pharmacy.onDutyDates, ...newDates}.toList()..sort();
    await _service.updatePharmacy(pharmacy.copyWith(onDutyDates: merged));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${newDates.length} date(s) ajoutée(s) à ${pharmacy.name}')),
      );
    }
  }

  Future<int?> _askNbDays(BuildContext context) async {
    final controller = TextEditingController(text: '1');
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Durée de la garde'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Nombre de jours (1-7)',
            helperText: 'Une garde dure généralement 7 jours',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(int.tryParse(controller.text) ?? 1),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _removeDate(
      BuildContext context, Pharmacy pharmacy, String dateIso) async {
    final remaining = pharmacy.onDutyDates.where((d) => d != dateIso).toList();
    await _service.updatePharmacy(pharmacy.copyWith(onDutyDates: remaining));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Garde du $_formatFr(_filterDate) retirée de ${pharmacy.name}')),
      );
    }
  }

  /// Import du JSON produit par scraper_unppci.py.
  Future<void> _showImportDialog(BuildContext context) async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importer les gardes (JSON)'),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: controller,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'JSON du scraper (gardes_2026_08.json)',
              helperText: 'Colle le contenu JSON ici, puis Enregistrer',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Importer'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;

    try {
      final data = jsonDecode(controller.text) as List;
      var created = 0;
      var updated = 0;
      for (final record in data) {
        if (record is! Map) continue;
        final name = record['nom'] as String? ?? '';
        final dates = (record['dates_garde'] as List? ?? [])
            .map((d) => d.toString())
            .toList();
        if (name.isEmpty || dates.isEmpty) continue;
        await _service.upsertGarde(
          name: name,
          dates: dates,
          quartier: record['quartier'] as String?,
          phone1: (record['telephones'] as List? ?? []).isNotEmpty
              ? (record['telephones'] as List).first.toString()
              : null,
          address: record['adresse'] as String?,
        );
        updated++;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Import terminé : $updated pharmacies mises à jour, $created créées')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'import : $e')),
        );
      }
    }
  }
}

/// Sélecteur de date rapide (aujourd'hui / +1j / calendrier).
class _DatePickerChip extends StatelessWidget {
  const _DatePickerChip({required this.date, required this.onChanged});

  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Jour précédent',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(date.subtract(const Duration(days: 1))),
        ),
        ActionChip(
          avatar: const Icon(Icons.calendar_today, size: 16),
          label: Text(_GuardesPageState._formatFr(date)),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(2025),
              lastDate: DateTime(2030),
              initialDate: date,
            );
            if (picked != null) onChanged(picked);
          },
        ),
        IconButton(
          tooltip: 'Jour suivant',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(date.add(const Duration(days: 1))),
        ),
      ],
    );
  }
}

class _GardeTile extends StatelessWidget {
  const _GardeTile({
    required this.pharmacy,
    required this.date,
    required this.onAddDate,
    required this.onRemoveDate,
  });

  final Pharmacy pharmacy;
  final String date;
  final VoidCallback onAddDate;
  final VoidCallback onRemoveDate;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.local_pharmacy, color: Colors.teal),
        title: Text(pharmacy.name),
        subtitle: Text(
          [
            if (pharmacy.commune != null) pharmacy.commune!,
            if (pharmacy.phone1 != null) pharmacy.phone1!,
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Retirer la garde de ce jour',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: onRemoveDate,
            ),
            IconButton(
              tooltip: 'Ajouter des dates de garde',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: onAddDate,
            ),
          ],
        ),
      ),
    );
  }
}

extension on FirestoreService {
  /// Crée ou met à jour une pharmacie avec ses dates de garde (import).
  Future<void> upsertGarde({
    required String name,
    required List<String> dates,
    String? quartier,
    String? phone1,
    String? address,
  }) async {
    final q = await FirebaseFirestore.instance
        .collection('pharmacies')
        .where('name', isEqualTo: name)
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) {
      final doc = q.docs.first;
      final oldDates = (doc.data()['onDutyDates'] as List?)?.cast<String>() ?? [];
      final merged = {...oldDates, ...dates}.toList()..sort();
      await doc.reference.update({
        'onDutyDates': merged,
        if (quartier != null && quartier.isNotEmpty) 'commune': quartier,
        if (phone1 != null && phone1.isNotEmpty) 'phone1': phone1,
        if (address != null && address.isNotEmpty) 'address': address,
      });
    } else {
      await FirebaseFirestore.instance.collection('pharmacies').add({
        'name': name,
        'commune': quartier ?? '',
        'phone1': phone1,
        'address': address ?? '',
        'onDutyDates': dates,
      });
    }
  }
}
