import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../../legal/presentation/widgets/legal_section.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final cubit = context.read<SettingsCubit>();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Devise',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Devise d’affichage',
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: state.currencyCode,
                    isExpanded: true,
                    items: SettingsCubit.supportedCurrencies()
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          ),
                        )
                        .toList(),
                    onChanged: state.isLoading
                        ? null
                        : (value) {
                            if (value == null) return;
                            cubit.setCurrencyCode(value);
                          },
                  ),
                ),
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
              const SizedBox(height: 20),
              // Partager l'app avec l'entourage (bouche-à-oreille).
              Card(
                child: ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('Partager PharmaScan'),
                  subtitle: const Text(
                    'Invite ton entourage à comparer les prix des '
                    'médicaments',
                  ),
                  onTap: () => Share.share(
                    'PharmaScan — Comparez. Payez juste.\n\n'
                    'Compare les prix des médicaments dans les pharmacies '
                    'près de chez toi et trouve les pharmacies de garde.\n\n'
                    'Télécharge ici : '
                    'https://play.google.com/store/apps/details'
                    '?id=com.softhubapp.scanapp',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const LegalSection(),
              const SizedBox(height: 24),
              // Version de l'app : indispensable pour le support et pour
              // vérifier qu'une mise à jour est bien arrivée.
              Center(
                child: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final info = snapshot.data;
                    return Text(
                      info == null
                          ? 'PharmaScan'
                          : 'PharmaScan ${info.version} '
                              '(${info.buildNumber})',
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

