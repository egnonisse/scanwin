import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/money/money_formatter.dart';
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
      appBar: AppBar(title: const Text('Rechercher')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.medication),
                  label: Text('Médicaments'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.local_pharmacy),
                  label: Text('Pharmacies'),
                ),
              ],
              selected: {_tabIndex},
              onSelectionChanged: (selection) =>
                  setState(() => _tabIndex = selection.first),
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
                onSubmitted: (value) =>
                    searchContext.read<SearchCubit>().search(value),
                decoration: InputDecoration(
                  labelText: 'Nom du médicament',
                  hintText: 'Ex : paracétamol, amoxicilline…',
                  border: const OutlineInputBorder(),
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
  }
}
