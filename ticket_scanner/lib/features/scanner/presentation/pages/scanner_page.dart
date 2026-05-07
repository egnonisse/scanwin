import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/ticket_extraction.dart';
import '../../domain/services/ticket_parser.dart';
import '../cubit/scanner_cubit.dart';
import '../cubit/scanner_state.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';

class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});

  Future<void> _requestPermissionAndScan(BuildContext context) async {
    final cubit = context.read<ScannerCubit>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Autoriser la caméra ?'),
          content: const Text(
            "Nous utilisons la caméra pour scanner votre ticket restaurant et "
            'en extraire les informations (montant, date, numéro de ticket).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continuer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final granted = await cubit.requestCameraPermission();
    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission caméra refusée.')),
        );
      }
      return;
    }

    await cubit.scanFromCamera();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ScannerCubit(parser: const TicketParser()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scanner un ticket'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: BlocBuilder<ScannerCubit, ScannerState>(
            builder: (context, state) {
              final extraction = state.extraction;

              return ListView(
                children: [
                  ElevatedButton.icon(
                    onPressed: state.isLoading
                        ? null
                        : () => _requestPermissionAndScan(context),
                    icon: const Icon(Icons.camera_alt),
                    label: Text(state.isLoading ? 'OCR en cours...' : 'Prendre une photo'),
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (extraction != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Résultats OCR',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _ExtractionCard(extraction: extraction),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        // On lit la devise via SettingsCubit pour afficher un montant formaté.
                        return BlocBuilder<SettingsCubit, SettingsState>(
                          builder: (context, settings) {
                            return FilledButton.icon(
                              onPressed: () {
                                // On envoie même si certains champs sont null :
                                // la page de confirmation laissera l’utilisateur éditer.
                                context.push(
                                  '/confirmation',
                                  extra: extraction,
                                );
                              },
                              icon: const Icon(Icons.check),
                              label: const Text('Continuer'),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExtractionCard extends StatelessWidget {
  const _ExtractionCard({required this.extraction});

  final TicketExtraction extraction;

  @override
  Widget build(BuildContext context) {
    // Devise gérée ailleurs (SettingsCubit). Ici on affiche brut si montant détecté.
    final montantTotal = extraction.montantTotal;
    final montantText = montantTotal == null
        ? '—'
        : montantTotal.toStringAsFixed(2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID ticket : ${extraction.ticketId ?? '—'}'),
            const SizedBox(height: 8),
            Text('Montant total : $montantText'),
            const SizedBox(height: 8),
            Text('Date ticket : ${extraction.dateTicket ?? '—'}'),
            const SizedBox(height: 8),
            Text('Enseigne : ${extraction.enseigne ?? '—'}'),
          ],
        ),
      ),
    );
  }
}

