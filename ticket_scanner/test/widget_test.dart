// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

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
    expect(find.text('Initialisation…'), findsOneWidget);
  });
}
