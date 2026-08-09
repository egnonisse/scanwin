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
              'La suppression retire aussi les prix associés de la recherche.',
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
    final scannedText = receipt.scannedAt == null
        ? ''
        : _formatDate(receipt.scannedAt!);
    final dateTicketText = receipt.dateTicket == null
        ? ''
        : 'Reçu du ${_formatDate(receipt.dateTicket!)}';

    final itemsPreview = receipt.items
        .take(3)
        .map((item) => '${item.name} (${item.price.toStringAsFixed(0)})')
        .join(', ');
    final more = receipt.items.length > 3
        ? '… +${receipt.items.length - 3}'
        : '';

    return Card(
      child: ListTile(
        leading: const Icon(Icons.receipt_long),
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
        trailing: IconButton(
          tooltip: 'Supprimer',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(context),
        ),
      ),
    );
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
