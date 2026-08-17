import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../models/receipt_doc.dart';
import '../services/firestore_service.dart';

class ReceiptsPage extends StatelessWidget {
  const ReceiptsPage({super.key});

  static const _service = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReceiptDoc>>(
      stream: _service.watchReceipts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final receipts = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Reçus soumis (${receipts.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Modifier = corriger les médicaments/montant. '
              'Valider = marquer le reçu contrôlé. '
              'Supprimer = retirer aussi les prix de la recherche.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (receipts.isEmpty)
              const Text('Aucun reçu soumis.')
            else
              ...receipts.map(
                (receipt) => _ReceiptTile(receipt: receipt),
              ),
          ],
        );
      },
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({required this.receipt});

  static const _service = FirestoreService();

  final ReceiptDoc receipt;

  @override
  Widget build(BuildContext context) {
    final scannedText =
        receipt.scannedAt == null ? '' : _formatDate(receipt.scannedAt!);
    final dateTicketText = receipt.dateTicket == null
        ? ''
        : 'Reçu du ${_formatDate(receipt.dateTicket!)}';

    final itemsPreview = receipt.items
        .take(3)
        .map((item) => '${item.name} (${item.price.toStringAsFixed(0)})')
        .join(', ');
    final more =
        receipt.items.length > 3 ? '… +${receipt.items.length - 3}' : '';

    return Card(
      child: ListTile(
        leading: Icon(
          receipt.isValidated ? Icons.verified : Icons.pending_outlined,
          color: receipt.isValidated ? Colors.green : Colors.orange,
        ),
        title: Text('${receipt.montant.toStringAsFixed(0)} FCFA'),
        subtitle: Text(
          [
            receipt.pharmacyId,
            if (dateTicketText.isNotEmpty) dateTicketText,
            if (scannedText.isNotEmpty) 'Scanné le $scannedText',
            if (itemsPreview.isNotEmpty) itemsPreview + more,
          ].join(' • '),
        ),
        isThreeLine: itemsPreview.isNotEmpty,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: receipt.photoPath != null
                  ? 'Modifier (photo + items)'
                  : 'Modifier',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _openEditDialog(context),
            ),
            if (!receipt.isValidated)
              IconButton(
                tooltip: 'Valider',
                icon: const Icon(Icons.check_circle_outline),
                onPressed: () => _service.validateReceipt(receipt.id),
              ),
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditDialog(BuildContext context) async {
    final result = await showDialog<_EditReceiptResult>(
      context: context,
      builder: (_) => _EditReceiptDialog(receipt: receipt),
    );
    if (result == null || !context.mounted) return;
    await _service.updateReceipt(
      receipt.id,
      items: result.items,
      montant: result.montant,
      dateTicket: result.dateTicket,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reçu corrigé et prix mis à jour.')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le reçu ?'),
        content: Text(
          'Reçu ${receipt.id.substring(0, 8)}… — '
          '${receipt.montant.toStringAsFixed(0)} FCFA. '
          'Les prix associés seront aussi supprimés.',
        ),
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
      await _service.deleteReceipt(receipt.id);
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _EditReceiptResult {
  const _EditReceiptResult({
    required this.items,
    required this.montant,
    required this.dateTicket,
  });

  final List<ReceiptItemDoc> items;
  final double montant;
  final DateTime? dateTicket;
}

class _EditReceiptDialog extends StatefulWidget {
  const _EditReceiptDialog({required this.receipt});

  final ReceiptDoc receipt;

  @override
  State<_EditReceiptDialog> createState() => _EditReceiptDialogState();
}

class _EditReceiptDialogState extends State<_EditReceiptDialog> {
  late final TextEditingController _montantController;
  late final TextEditingController _dateController;
  late final List<_ItemEditorRow> _rows;

  /// URL de la photo (null si le reçu n'a pas de photo).
  late final Future<String>? _photoUrlFuture;

  @override
  void initState() {
    super.initState();
    _montantController = TextEditingController(
      text: widget.receipt.montant.toStringAsFixed(0),
    );
    _dateController = TextEditingController(
      text: widget.receipt.dateTicket == null
          ? ''
          : _formatDate(widget.receipt.dateTicket!),
    );
    _rows = widget.receipt.items
        .map((item) => _ItemEditorRow(item: item))
        .toList();
    final photoPath = widget.receipt.photoPath;
    _photoUrlFuture = photoPath == null
        ? null
        : FirebaseStorage.instance.ref(photoPath).getDownloadURL();
  }

  @override
  void dispose() {
    _montantController.dispose();
    _dateController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _montantController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Montant total (FCFA)',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _dateController,
            decoration: const InputDecoration(
              labelText: 'Date du reçu (JJ/MM/AAAA) — laisser vide si inconnue',
            ),
          ),
          const SizedBox(height: 16),
          Text('Médicaments', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ..._rows.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: entry.value.nameField,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: entry.value.priceField,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: entry.value.quantityField,
                  ),
                  IconButton(
                    tooltip: 'Retirer la ligne',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      setState(() {
                        _rows.removeAt(entry.key);
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _rows.add(_ItemEditorRow.empty());
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un médicament'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoto() {
    return FutureBuilder<String>(
      future: _photoUrlFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              snapshot.data!,
              fit: BoxFit.contain,
              width: 360,
              height: 480,
            ),
          );
        }
        if (snapshot.hasError) {
          return Container(
            width: 360,
            height: 480,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Photo inaccessible : ${snapshot.error}'),
              ),
            ),
          );
        }
        return Container(
          width: 360,
          height: 480,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _photoUrlFuture != null;
    return AlertDialog(
      title: const Text('Modifier le reçu'),
      content: SizedBox(
        width: hasPhoto ? 880 : 520,
        child: hasPhoto
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPhoto(),
                  const SizedBox(width: 16),
                  Expanded(child: _buildForm()),
                ],
              )
            : _buildForm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }

  void _save() {
    final montant = double.tryParse(
      _montantController.text.replaceAll(',', '.'),
    );
    if (montant == null || montant <= 0) {
      _showError('Montant invalide.');
      return;
    }

    final items = <ReceiptItemDoc>[];
    for (final row in _rows) {
      final name = row.nameController.text.trim();
      final price = double.tryParse(row.priceController.text.replaceAll(',', '.'));
      final quantity = int.tryParse(row.quantityController.text) ?? 1;
      if (name.isEmpty || price == null || price <= 0) {
        _showError('Chaque ligne doit avoir un nom et un prix valides.');
        return;
      }
      items.add(ReceiptItemDoc(name: name, price: price, quantity: quantity));
    }
    if (items.isEmpty) {
      _showError('Le reçu doit contenir au moins un médicament.');
      return;
    }

    Navigator.of(context).pop(
      _EditReceiptResult(
        items: items,
        montant: montant,
        dateTicket: _parseDate(_dateController.text),
      ),
    );
  }

  DateTime? _parseDate(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;
    final parts = trimmed.split(RegExp(r'[/.\-]'));
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _ItemEditorRow {
  _ItemEditorRow({required ReceiptItemDoc item})
      : nameController = TextEditingController(text: item.name),
        priceController =
            TextEditingController(text: item.price.toStringAsFixed(0)),
        quantityController = TextEditingController(text: '${item.quantity}');

  _ItemEditorRow.empty()
      : nameController = TextEditingController(),
        priceController = TextEditingController(),
        quantityController = TextEditingController(text: '1');

  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController quantityController;

  Widget get nameField => TextField(
        controller: nameController,
        decoration: const InputDecoration(labelText: 'Nom'),
      );

  Widget get priceField => TextField(
        controller: priceController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Prix'),
      );

  Widget get quantityField => TextField(
        controller: quantityController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Qté'),
      );

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    quantityController.dispose();
  }
}
