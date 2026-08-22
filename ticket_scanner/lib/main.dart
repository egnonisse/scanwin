import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/app.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsCubit = SettingsCubit();
  // Attend la détection de devise (zone XOF) AVANT le lancement : le doc
  // utilisateur créé au splash portera la bonne devise.
  await settingsCubit.load();
  runApp(
    BlocProvider.value(
      value: settingsCubit,
      child: const TicketScannerApp(),
    ),
  );
}
