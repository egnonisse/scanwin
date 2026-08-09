import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/money/money_formatter.dart';
import '../../data/repositories/firebase_price_repository.dart';
import '../../domain/entities/price_entry.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_state.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rechercher un médicament')),
      body: BlocProvider(
        create: (_) => SearchCubit(repository: const FirebasePriceRepository()),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) =>
                    context.read<SearchCubit>().search(value),
                decoration: InputDecoration(
                  labelText: 'Nom du médicament',
                  hintText: 'Ex : paracétamol, amoxicilline…',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () =>
                        context.read<SearchCubit>().search(_controller.text),
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
                        return const Center(child: CircularProgressIndicator());
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
                          child: Text('Aucun prix trouvé pour ce médicament.'),
                        );
                      }
                      return ListView.builder(
                        itemCount: state.results.length,
                        itemBuilder: (context, index) => _PriceResultTile(
                          entry: state.results[index],
                          currencyCode: settings.currencyCode,
                        ),
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

class _PriceResultTile extends StatelessWidget {
  const _PriceResultTile({
    required this.entry,
    required this.currencyCode,
  });

  final PriceEntry entry;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final pharmacyName = entry.pharmacyName ?? entry.pharmacyId;
    final dateText = entry.scannedAt == null
        ? null
        : 'Scanné le ${_formatDate(entry.scannedAt!)}';

    return Card(
      child: ListTile(
        leading: const Icon(Icons.medication),
        title: Text(
          MoneyFormatter.formatAmount(entry.price, currencyCode),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          [
            pharmacyName,
            if (dateText != null) dateText,
          ].join(' • '),
        ),
        trailing: entry.quantity > 1
            ? Text('x${entry.quantity}')
            : null,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
