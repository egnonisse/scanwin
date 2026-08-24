// Test de démarrage : l'app se lance sans crash et affiche le splash
// officiel (image) pendant l'initialisation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:ticket_scanner/app/app.dart';
import 'package:ticket_scanner/features/settings/presentation/cubit/settings_cubit.dart';

void main() {
  testWidgets('L’app démarre sans crash', (WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => SettingsCubit(),
        child: const TicketScannerApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));

    // Le splash officiel (image) est affiché pendant l'initialisation.
    expect(
      find.byWidgetPredicate(
        (w) => w is Image && (w.image as AssetImage).assetName ==
            'assets/images/splash_full.png',
      ),
      findsOneWidget,
    );
  });
}
