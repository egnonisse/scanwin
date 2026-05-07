import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money/money_formatter.dart';
import '../../data/repositories/firebase_home_repository.dart';
import '../../domain/entities/points_event.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = FirebaseHomeRepository(
      auth: FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
    );

    return BlocProvider(
      create: (_) => HomeCubit(repository: repository)..start(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ScanWin'),
          actions: [
            IconButton(
              onPressed: () => context.push('/scanner'),
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scanner un ticket',
            ),
            IconButton(
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings),
              tooltip: 'Réglages',
            ),
          ],
        ),
        body: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, settings) {
            return BlocBuilder<HomeCubit, HomeState>(
              builder: (context, home) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _PointsHeader(points: home.points),
                    const SizedBox(height: 12),
                    Text(
                      'Devise actuelle : ${settings.currencyCode}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (home.errorMessage != null)
                      Text(
                        home.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Historique',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (home.isLoading && home.events.isEmpty)
                      const Center(child: CircularProgressIndicator())
                    else if (home.events.isEmpty)
                      const Text('Aucun événement pour le moment.')
                    else
                      ...home.events.map(
                        (e) => _PointsEventTile(
                          event: e,
                          currencyCode: settings.currencyCode,
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PointsHeader extends StatelessWidget {
  const _PointsHeader({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.stars),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$points points',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointsEventTile extends StatelessWidget {
  const _PointsEventTile({
    required this.event,
    required this.currencyCode,
  });

  final PointsEvent event;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[];
    if (event.ticketId != null) subtitleParts.add('Ticket: ${event.ticketId}');
    if (event.amount != null) {
      subtitleParts.add(
        'Montant: ${MoneyFormatter.formatAmount(event.amount!, currencyCode)}',
      );
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.receipt_long),
        title: Text('+${event.pointsAdded} points'),
        subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' • ')),
      ),
    );
  }
}

