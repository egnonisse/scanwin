import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/analytics/app_analytics.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../pharmacy/domain/entities/pharmacy.dart';
import '../../../pharmacy/presentation/pages/pharmacies_page.dart';
import '../../../pharmacy/presentation/widgets/pharmacy_sheet.dart';
import '../../data/repositories/firebase_price_repository.dart';
import '../../domain/entities/price_entry.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_state.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';

/// Vue recherche : 2 onglets.
/// - Médicaments : recherche par nom, résultats groupés par médicament,
///   chaque médicament déplie la liste des pharmacies triées par prix croissant.
/// - Pharmacies : pharmacies de garde / communes, triées par distance.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _controller;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _TabBar(
              index: _tabIndex,
              onChanged: (i) => setState(() => _tabIndex = i),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _buildMedicationTab(context),
                const PharmaciesPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationTab(BuildContext context) {
    final query = _controller.text.trim();
    return BlocProvider(
      create: (_) {
        final cubit =
            SearchCubit(repository: const FirebasePriceRepository());
        if (query.length >= 3) {
          cubit.search(query);
        }
        return cubit;
      },
      child: Builder(
        builder: (searchContext) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  AppAnalytics().logSearch(query: value);
                  searchContext.read<SearchCubit>().search(value);
                },
                decoration: InputDecoration(
                  labelText: 'Nom du médicament',
                  hintText: 'Ex : paracétamol, amoxicilline…',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => searchContext
                        .read<SearchCubit>()
                        .search(_controller.text),
                  ),
                ),
              ),
            ),
            Expanded(
              child: BlocBuilder<SettingsCubit, SettingsState>(
                builder: (context, settings) {
                  return BlocBuilder<SearchCubit, SearchState>(
                    builder: (context, state) {
                      if (state.isSearching) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      if (state.query.isEmpty) {
                        return const Center(
                          child: Text('Tape le nom d\'un médicament '
                              '(3 lettres minimum).'),
                        );
                      }
                      if (state.errorMessage != null) {
                        return Center(
                          child: Text(
                            state.errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        );
                      }
                      if (state.results.isEmpty) {
                        return const Center(
                          child: Text(
                            'Aucun prix trouvé pour ce médicament.',
                          ),
                        );
                      }
                      return _MedicationGroupedList(
                        entries: state.results,
                        currencyCode: settings.currencyCode,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Liste des résultats groupés par médicament ; chaque médicament est un
/// expansion tile dont le contenu liste les pharmacies triées par prix
/// croissant (moins cher en premier).
class _MedicationGroupedList extends StatelessWidget {
  const _MedicationGroupedList({
    required this.entries,
    required this.currencyCode,
  });

  final List<PriceEntry> entries;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<PriceEntry>>{};
    for (final entry in entries) {
      groups.putIfAbsent(entry.medicationName, () => []).add(entry);
    }

    // Trier chaque groupe par prix croissant.
    for (final list in groups.values) {
      list.sort((a, b) => a.price.compareTo(b.price));
    }

    final sortedNames = groups.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    return ListView.builder(
      itemCount: sortedNames.length,
      itemBuilder: (context, index) {
        final name = sortedNames[index];
        final group = groups[name]!;
        final lowest = group.first;
        return Card(
          child: ExpansionTile(
            leading: const Icon(Icons.medication),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Dès ${MoneyFormatter.formatAmount(lowest.price, currencyCode)} '
              '— ${group.length} pharmacie${group.length > 1 ? 's' : ''}',
            ),
            children: [
              for (final entry in group)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.local_pharmacy_outlined),
                  title: Text(
                    entry.pharmacyName ?? entry.pharmacyId,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    MoneyFormatter.formatAmount(entry.price, currencyCode),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => _openPharmacy(context, entry.pharmacyId),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Ouvre la fiche pharmacie (récupère le doc par id, puis bottom sheet).
  Future<void> _openPharmacy(BuildContext context, String pharmacyId) async {
    final doc = await FirebaseFirestore.instance
        .collection('pharmacies')
        .doc(pharmacyId)
        .get();
    if (!doc.exists || !context.mounted) return;
    final data = doc.data() ?? <String, dynamic>{};
    final pharmacy = Pharmacy(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      address: data['address'] as String?,
      commune: data['commune'] as String?,
      phone1: data['phone1'] as String?,
      phone2: data['phone2'] as String?,
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
      onDutyDates: (data['onDutyDates'] as List?)?.cast<String>() ?? const [],
    );
    await showPharmacySheet(context, pharmacy: pharmacy);
    AppAnalytics().logPharmacyOpened(pharmacyId: pharmacyId);
  }
}

/// Onglets Médicaments / Pharmacies au style design system (fond gris,
/// onglet actif vert, arrondis 5px).
class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          _TabItem(
            label: 'Médicaments',
            icon: Icons.medication,
            active: index == 0,
            onTap: () => onChanged(0),
          ),
          _TabItem(
            label: 'Pharmacies',
            icon: Icons.local_pharmacy,
            active: index == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card - 1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.card - 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? AppColors.onPrimary : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: active
                          ? AppColors.onPrimary
                          : AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
