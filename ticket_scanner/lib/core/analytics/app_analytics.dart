import 'package:firebase_analytics/firebase_analytics.dart';

/// Service d'analytics centralisé PharmaScan.
///
/// Tous les événements d'utilisation passent par ici (DRY) :
/// - scan : démarrage / succès / échec OCR
/// - recherche : médicaments / pharmacies consultés
/// - gamification : points crédités
/// Les données restent dans le Firebase du projet (pas de partage tiers).
class AppAnalytics {
  AppAnalytics({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  static const _logPrefix = '[Analytics]';

  /// Écran affiché (auto-log par Firebase, wrapper pour cohérence).
  Future<void> logScreen(String screenName) async {
    await _safe(() => _analytics.logEvent(
          name: 'screen_view',
          parameters: {'screen': screenName},
        ));
  }

  /// L'utilisateur lance un scan (caméra ou galerie).
  Future<void> logScanStarted({required String source}) async {
    await _safe(() => _analytics.logEvent(
          name: 'scan_started',
          parameters: {'source': source},
        ));
  }

  /// L'OCR a réussi et une extraction a été produite.
  Future<void> logScanSuccess({required int itemCount}) async {
    await _safe(() => _analytics.logEvent(
          name: 'scan_success',
          parameters: {'item_count': itemCount},
        ));
  }

  /// L'OCR a échoué ou a été annulé.
  Future<void> logScanFailed({required String reason}) async {
    await _safe(() => _analytics.logEvent(
          name: 'scan_failed',
          parameters: {'reason': reason},
        ));
  }

  /// Une recherche de médicament a été effectuée.
  Future<void> logSearch({required String query}) async {
    await _safe(() => _analytics.logEvent(
          name: 'search_performed',
          parameters: {'query': query},
        ));
  }

  /// Une pharmacie a été ouverte (fiche / appel).
  Future<void> logPharmacyOpened({required String pharmacyId}) async {
    await _safe(() => _analytics.logEvent(
          name: 'pharmacy_opened',
          parameters: {'pharmacy_id': pharmacyId},
        ));
  }

  /// Des points ont été crédités après validation d'un ticket.
  Future<void> logPointsEarned({required int points}) async {
    await _safe(() => _analytics.logEvent(
          name: 'points_earned',
          parameters: {'points': points},
        ));
  }

  /// Un ticket a été soumis (confirmation finale).
  Future<void> logTicketSubmitted({required double amount}) async {
    await _safe(() => _analytics.logEvent(
          name: 'ticket_submitted',
          parameters: {'amount': amount},
        ));
  }

  /// Exécute l'appel analytics sans faire planter l'app en cas d'échec.
  /// L'analytics ne doit JAMAIS bloquer l'expérience utilisateur.
  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      // Échec silencieux : analytics = auxiliaire, pas critique.
      debugPrintSafely('$_logPrefix échec: $e');
    }
  }

  static void debugPrintSafely(String message) {
    // ignore: avoid_print
    print(message);
  }
}
