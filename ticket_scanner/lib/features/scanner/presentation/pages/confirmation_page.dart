import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money/money_formatter.dart';
import '../../domain/entities/ticket_extraction.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';

class ConfirmationPage extends StatefulWidget {
  const ConfirmationPage({super.key});

  @override
  State<ConfirmationPage> createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends State<ConfirmationPage> {
  final TextEditingController _ticketIdController = TextEditingController();
  final TextEditingController _montantController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _enseigneController = TextEditingController();

  TicketExtraction? _initialExtraction;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final extra = GoRouterState.of(context).extra;
    final extraction = extra is TicketExtraction ? extra : null;

    if (extraction == null) return;
    if (_initialExtraction == null) {
      _initialExtraction = extraction;
      _ticketIdController.text = extraction.ticketId ?? '';
      _montantController.text = extraction.montantTotal?.toStringAsFixed(2) ?? '';
      _dateController.text = extraction.dateTicket ?? '';
      _enseigneController.text = extraction.enseigne ?? '';
    }
  }

  @override
  void dispose() {
    _ticketIdController.dispose();
    _montantController.dispose();
    _dateController.dispose();
    _enseigneController.dispose();
    super.dispose();
  }

  double? _parseAmount(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    final extraction = extra is TicketExtraction ? extra : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmation')),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          if (extraction == null || _initialExtraction == null) {
            return const Center(child: Text('Aucune donnée OCR.'));
          }

          final amount = _parseAmount(_montantController.text);
          final formattedAmount = amount == null
              ? null
              : MoneyFormatter.formatAmount(amount, settings.currencyCode);

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
                  controller: _ticketIdController,
                  decoration: const InputDecoration(
                    labelText: 'ID ticket (numéro de ticket / code-barres)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _montantController,
                  decoration: const InputDecoration(
                    labelText: 'Montant total',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date du ticket (ex: 31/03/2025)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _enseigneController,
                  decoration: const InputDecoration(
                    labelText: 'Enseigne / Commerçant',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'MVP: validation non branchée (Cloud Function plus tard).',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Valider le ticket'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

