import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/scanner/presentation/pages/confirmation_page.dart';
import '../features/scanner/presentation/pages/scanner_page.dart';
import '../features/search/presentation/pages/search_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/splash/presentation/pages/splash_page.dart';

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashPage(),
    ),
    // Routes racines (pas de sous-route du splash) : le back depuis la home
    // quitte l'app au lieu de revenir au splash et relancer l'init Firebase.
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/scanner',
      builder: (context, state) => const ScannerPage(),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) =>
          SearchPage(initialQuery: state.uri.queryParameters['q'] ?? ''),
    ),
    GoRoute(
      path: '/confirmation',
      builder: (context, state) => const ConfirmationPage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);

class TicketScannerApp extends StatelessWidget {
  const TicketScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pharmascan',
      theme: buildAppTheme(),
      routerConfig: _router,
    );
  }
}

