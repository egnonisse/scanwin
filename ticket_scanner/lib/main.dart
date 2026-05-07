import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/app.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsCubit = SettingsCubit()..load();
  runApp(
    BlocProvider.value(
      value: settingsCubit,
      child: const TicketScannerApp(),
    ),
  );
}
