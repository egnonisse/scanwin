import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Service de notifications push (FCM).
///
/// - Demande la permission (Android 13+ : POST_NOTIFICATIONS)
/// - Récupère le token FCM et le sauvegarde dans users/{uid}/fcmToken
/// - Réagit au refresh de token (réinstallation, etc.)
class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Initialise le push : permission + token + sauvegarde.
  /// Jamais bloquant : en cas d'échec (permission refusée, réseau), on
  /// continue silencieusement — le push est une fonctionnalité bonus.
  Future<void> init() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // Permission refusée ou non supportée : ignorer.
    }

    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveToken(token);
      }
    } catch (_) {
      // Token indisponible (ex : pas de Play Services) : ignorer.
    }

    // Si le token change (réinstallation, reset), on le met à jour.
    _messaging.onTokenRefresh.listen((token) async {
      try {
        await _saveToken(token);
      } catch (_) {}
    });
  }

  Future<void> _saveToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).update({
      'fcmToken': token,
    });
  }
}
