import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money/money_formatter.dart';
import '../../data/repositories/firebase_home_repository.dart';
import '../../domain/entities/contributor_profile.dart';
import '../../domain/entities/points_event.dart';
import '../../../../features/pharmacy/domain/entities/pharmacy.dart';
import '../../../../features/pharmacy/data/repositories/firebase_pharmacy_repository.dart';
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
          title: const Text('Pharmascan'),
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
                    _SearchBar(onSubmitted: (query) {
                      context.push('/search');
                    }),
                    const SizedBox(height: 16),
                    _ContributorHeader(profile: home.profile),
                    const SizedBox(height: 16),
                    const _OnDutySection(),
                    const SizedBox(height: 16),
                    const _PopularMedsSection(),
                    const SizedBox(height: 16),
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

/// Barre de recherche principale : tap = ouvre la vue recherche (2 onglets).
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onSubmitted});

  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onSubmitted(''),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: 'Rechercher un médicament ou une pharmacie…',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        child: const SizedBox.shrink(),
      ),
    );
  }
}

/// Badge contributeur (points + reçus validés + niveau).
class _ContributorHeader extends StatelessWidget {
  const _ContributorHeader({required this.profile});

  final ContributorProfile profile;

  @override
  Widget build(BuildContext context) {
    final tier = profile.tier;
    final next = tier.nextThreshold;
    final progressLabel = next == null
        ? 'Niveau maximum'
        : 'Encore ${next - profile.contributions} reçus '
            'pour passer ${tier.label} → ${_nextTierLabel(tier)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _tierIcon(tier),
                  color: _tierColor(tier),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Contributeur ${tier.label}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${profile.points} pts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${profile.contributions} reçu'
              '${profile.contributions > 1 ? 's' : ''} scanné'
              '${profile.contributions > 1 ? 's' : ''} · $progressLabel',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  static IconData _tierIcon(ContributorTier tier) => switch (tier) {
        ContributorTier.bronze => Icons.emoji_events,
        ContributorTier.silver => Icons.workspace_premium,
        ContributorTier.gold => Icons.military_tech,
      };

  static Color _tierColor(ContributorTier tier) => switch (tier) {
        ContributorTier.bronze => const Color(0xFF9C6B30),
        ContributorTier.silver => const Color(0xFF8E9AAF),
        ContributorTier.gold => const Color(0xFFD4AF37),
      };

  static String _nextTierLabel(ContributorTier tier) => switch (tier) {
        ContributorTier.bronze => 'Argent',
        ContributorTier.silver => 'Or',
        ContributorTier.gold => '',
      };
}

/// Pharmacies de garde aujourd'hui, triées par distance (si GPS dispo).
class _OnDutySection extends StatelessWidget {
  const _OnDutySection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Pharmacy>>(
      stream: const FirebasePharmacyRepository().watchPharmacies(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final today = _todayIso();
        final onDuty = snapshot.data!
            .where((p) => p.isOnDutyOn(today))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Pharmacies de garde',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/search'),
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            if (onDuty.isEmpty)
              const Text('Aucune pharmacie de garde aujourd\'hui.')
            else
              ...onDuty.take(3).map(
                (p) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.local_pharmacy),
                  title: Text(p.name),
                  subtitle: p.commune == null
                      ? null
                      : Text(p.commune!),
                ),
              ),
          ],
        );
      },
    );
  }

  static String _todayIso() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }
}

/// Chips rapides : médicaments populaires (recherche pré-remplie).
class _PopularMedsSection extends StatelessWidget {
  const _PopularMedsSection();

  static const _meds = [
    'paracétamol',
    'amoxicilline',
    'ibuprofène',
    'vitamine c',
    'doliprane',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Médicaments populaires',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final med in _meds)
              ActionChip(
                avatar: const Icon(Icons.medication, size: 18),
                label: Text(med),
                onPressed: () => context.push('/search?q=${Uri.encodeQueryComponent(med)}'),
              ),
          ],
        ),
      ],
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
    if (event.receiptId != null) {
      subtitleParts.add('Reçu: ${event.receiptId!.substring(0, 8)}…');
    }
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
