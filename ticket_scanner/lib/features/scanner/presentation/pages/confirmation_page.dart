import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money/money_formatter.dart';
import '../../data/repositories/firebase_receipt_repository.dart';
import '../../domain/entities/receipt_extraction.dart';
import '../cubit/confirmation_cubit.dart';
import '../cubit/confirmation_state.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';

class ConfirmationPage extends StatefulWidget {
  const ConfirmationPage({super.key});

  @override
  State<ConfirmationPage> createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends State<ConfirmationPage> {
  final TextEditingController _pharmacyController = TextEditingController();
  final TextEditingController _montantController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  /// Lignes de médicaments éditables (draft local).
  List<ReceiptItem> _items = [];

  /// Chemin de la photo du reçu (envoyée au serveur pour archivage).
  String? _imagePath;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final extra = GoRouterState.of(context).extra;
    final extraction = switch (extra) {
      (final ReceiptExtraction e, final String? _) => e,
      final ReceiptExtraction e => e,
      _ => null,
    };
    final imagePath = switch (extra) {
      (final ReceiptExtraction _, final String? path) => path,
      _ => null,
    };
    if (extraction == null || _initialized) return;

    _initialized = true;
    _pharmacyController.text = extraction.pharmacyName ?? '';
    _montantController.text = extraction.montantTotal?.toStringAsFixed(2) ?? '';
    _dateController.text = extraction.dateTicket ?? '';
    _items = List<ReceiptItem>.from(extraction.items);
    _imagePath = imagePath;
  }

  @override
  void dispose() {
    _pharmacyController.dispose();
    _montantController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _updateItem(int index, String name, double price) {
    setState(() {
      _items[index] = ReceiptItem(name: name, price: price);
    });
  }

  void _addItem() {
    setState(() {
      _items.add(const ReceiptItem(name: '', price: 0));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    final extraction = switch (extra) {
      (final ReceiptExtraction e, final String? _) => e,
      final ReceiptExtraction e => e,
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmation')),
      body: BlocProvider(
        create: (_) =>
            ConfirmationCubit(repository: const FirebaseReceiptRepository()),
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, settings) {
            if (extraction == null || !_initialized) {
              return const Center(child: Text('Aucune donnée OCR.'));
            }
            return _ConfirmationForm(
              settings: settings,
              pharmacyController: _pharmacyController,
              montantController: _montantController,
              dateController: _dateController,
              items: _items,
              imagePath: _imagePath,
              onUpdateItem: _updateItem,
              onAddItem: _addItem,
              onRemoveItem: _removeItem,
            );
          },
        ),
      ),
    );
  }
}

class _ConfirmationForm extends StatelessWidget {
  const _ConfirmationForm({
    required this.settings,
    required this.pharmacyController,
    required this.montantController,
    required this.dateController,
    required this.items,
    required this.imagePath,
    required this.onUpdateItem,
    required this.onAddItem,
    required this.onRemoveItem,
  });

  final SettingsState settings;
  final TextEditingController pharmacyController;
  final TextEditingController montantController;
  final TextEditingController dateController;
  final List<ReceiptItem> items;
  final String? imagePath;
  final void Function(int, String, double) onUpdateItem;
  final VoidCallback onAddItem;
  final void Function(int) onRemoveItem;

  void _onSuccess(BuildContext context, ConfirmationState state) {
    context.read<ConfirmationCubit>().reset();
    context.go('/home');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('+${state.pointsAdded} points crédités !')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final montant = double.tryParse(montantController.text.replaceAll(',', '.'));
    final formattedAmount = montant == null
        ? null
        : MoneyFormatter.formatAmount(montant, settings.currencyCode);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text(
            'Devise : ${settings.currencyCode}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (formattedAmount != null) Text(formattedAmount),
          const SizedBox(height: 24),
          TextField(
            controller: pharmacyController,
            decoration: const InputDecoration(
              labelText: 'Pharmacie',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: dateController,
            decoration: const InputDecoration(
              labelText: 'Date du reçu (ex: 31/03/2025)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: montantController,
            decoration: const InputDecoration(
              labelText: 'Montant total',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Médicaments (${items.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton.icon(
                onPressed: onAddItem,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('Aucune ligne. Ajoute au moins un médicament.')
          else
            ...List.generate(
              items.length,
              (index) => _ItemEditor(
                key: ValueKey(index),
                initialName: items[index].name,
                initialPrice: items[index].price,
                onChanged: (name, price) => onUpdateItem(index, name, price),
                onRemove: () => onRemoveItem(index),
              ),
            ),
          const SizedBox(height: 24),
          BlocConsumer<ConfirmationCubit, ConfirmationState>(
            listener: (context, state) {
              if (state.status == ConfirmationStatus.success) {
                _onSuccess(context, state);
              }
            },
            builder: (context, state) {
              if (state.status == ConfirmationStatus.submitting) {
                return const Center(child: CircularProgressIndicator());
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      context.read<ConfirmationCubit>().submit(
                            pharmacyName: pharmacyController.text,
                            dateText: dateController.text,
                            montantText: montantController.text,
                            items: items,
                            imagePath: imagePath,
                          );
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Valider le reçu'),
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Éditeur d'une ligne de médicament (nom + prix), autonome en saisie.
class _ItemEditor extends StatefulWidget {
  const _ItemEditor({
    super.key,
    required this.initialName,
    required this.initialPrice,
    required this.onChanged,
    required this.onRemove,
  });

  final String initialName;
  final double initialPrice;
  final void Function(String name, double price) onChanged;
  final VoidCallback onRemove;

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _priceController = TextEditingController(
      text: widget.initialPrice > 0 ? widget.initialPrice.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _notify() {
    final price = double.tryParse(_priceController.text.replaceAll(',', '.'));
    widget.onChanged(_nameController.text.trim(), price ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _nameController,
              onChanged: (_) => _notify(),
              decoration: const InputDecoration(
                labelText: 'Médicament',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _priceController,
              onChanged: (_) => _notify(),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Prix',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onRemove,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer',
          ),
        ],
      ),
    );
  }
}
