import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/entities/pharmacy.dart';
import '../cubit/pharmacies_cubit.dart';
import '../widgets/pharmacy_sheet.dart';

/// Vue des pharmacies : triées par distance (si GPS accepté) et filtrables
/// par commune. Les pharmacies de garde portent un badge.
class PharmaciesPage extends StatefulWidget {
  const PharmaciesPage({super.key});

  @override
  State<PharmaciesPage> createState() => _PharmaciesPageState();
}

class _PharmaciesPageState extends State<PharmaciesPage> {
  String _communeFilter = '';
  bool _showOnDutyOnly = false;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PharmaciesCubit()..start(),
      child: Builder(
        builder: (context) => BlocBuilder<PharmaciesCubit, PharmaciesState>(
          builder: (context, state) {
            if (state is PharmaciesLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is! PharmaciesReady) {
              return const Center(child: Text('Chargement…'));
            }
            return _buildList(context, state);
          },
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, PharmaciesReady state) {
    final sorted = state.sortedByDistance();
    final communes = sorted
        .map((p) => p.commune)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    final todayIso = _todayIso();

    final filtered = sorted.where((p) {
      if (_showOnDutyOnly && !p.isOnDutyOn(todayIso)) return false;
      if (_communeFilter.isNotEmpty &&
          (p.commune ?? '') != _communeFilter) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: _communeFilter.isEmpty ? null : _communeFilter,
                hint: const Text('Toutes les communes'),
                items: [
                  for (final c in communes)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _communeFilter = v ?? ''),
              ),
              FilterChip(
                label: const Text('De garde aujourd\'hui'),
                selected: _showOnDutyOnly,
                onSelected: (v) =>
                    setState(() => _showOnDutyOnly = v),
              ),
            ],
          ),
        ),
        if (state.userLat == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Position GPS non disponible — pharmacies triées par nom.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('Aucune pharmacie trouvée.'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    return _PharmacyTile(
                      pharmacy: p,
                      distanceKm: state.userLat == null
                          ? null
                          : p.distanceKmFrom(
                              state.userLat!, state.userLng!),
                      isOnDuty: p.isOnDutyOn(todayIso),
                      onTap: () => showPharmacySheet(
                        context,
                        pharmacy: p,
                        distanceKm: state.userLat == null
                            ? null
                            : p.distanceKmFrom(
                                state.userLat!, state.userLng!),
                        isOnDuty: p.isOnDutyOn(todayIso),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _todayIso() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }
}

class _PharmacyTile extends StatelessWidget {
  const _PharmacyTile({
    required this.pharmacy,
    required this.distanceKm,
    required this.isOnDuty,
    required this.onTap,
  });

  final Pharmacy pharmacy;
  final double? distanceKm;
  final bool isOnDuty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      if (pharmacy.address != null) pharmacy.address!,
      if (pharmacy.commune != null) pharmacy.commune!,
    ].join(' • ');

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          isOnDuty ? Icons.local_pharmacy : Icons.storefront,
          color: isOnDuty ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                pharmacy.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (isOnDuty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'DE GARDE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: distanceKm == null
            ? null
            : Text(
                _formatDistance(distanceKm!),
                style: Theme.of(context).textTheme.titleSmall,
              ),
      ),
    );
  }

  String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }
}

/// Dialogue explicatif avant la demande de permission (conformité stores :
/// toute permission doit être précédée d'une explication concrète).
Future<bool> showLocationPermissionDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Localisation'),
      content: const Text(
        'Nous utilisons ta position pour afficher les pharmacies '
        'les plus proches de toi, classées par distance.\n\n'
        'Ta position n\'est jamais enregistrée : elle sert uniquement '
        'au calcul de distance, directement sur ton téléphone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Plus tard'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Autoriser'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Demande la permission avec dialogue explicatif d'abord.
Future<void> requestLocationWithDialog(BuildContext context) async {
  final ok = await showLocationPermissionDialog(context);
  if (!ok) return;
  await Geolocator.requestPermission();
}
