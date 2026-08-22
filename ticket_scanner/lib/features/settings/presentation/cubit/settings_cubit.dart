import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit()
      : super(
          const SettingsState(
            currencyCode: 'EUR',
            isLoading: false,
            errorMessage: null,
          ),
        );

  static const _currencyKey = 'currency_code';
  static const _allowedCurrencies = {'EUR', 'USD', 'GBP', 'CHF', 'XOF'};

  /// Pays de la zone XOF (UEMOA) — codes pays ISO des locales système.
  static const _xofCountries = {
    'CI', // Côte d'Ivoire
    'BJ', // Bénin
    'BF', // Burkina Faso
    'ML', // Mali
    'NE', // Niger
    'SN', // Sénégal
    'TG', // Togo
    'GW', // Guinée-Bissau
  };

  /// Détecte la devise selon la zone de l'utilisateur (locale du téléphone,
  /// ex : fr_CI → XOF). Aucune permission ni réseau requis.
  static String? detectRegionalCurrency() {
    try {
      final locale = Platform.localeName.toUpperCase();
      final parts = locale.split('_');
      if (parts.length == 2 && _xofCountries.contains(parts[1])) {
        return 'XOF';
      }
    } catch (_) {
      // Locale illisible : pas de détection.
    }
    return null;
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_currencyKey);
      if (stored != null && _allowedCurrencies.contains(stored)) {
        emit(state.copyWith(currencyCode: stored, isLoading: false));
        return;
      }

      // Pas de devise enregistrée : détection automatique de la zone.
      // (Le choix manuel reste prioritaire une fois enregistré.)
      final detected = detectRegionalCurrency();
      if (detected != null) {
        await prefs.setString(_currencyKey, detected);
      }
      emit(
        state.copyWith(
          currencyCode: detected ?? 'EUR',
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Impossible de charger les réglages.',
        ),
      );
    }
  }

  /// Synchronise la devise locale avec le cloud (users/{uid}.currencyCode).
  /// Priorité au cloud si présent. À appeler APRÈS Firebase.initializeApp.
  /// Les échecs sont silencieux : la devise locale reste utilisable.
  Future<void> syncWithCloud() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return;
      final cloudCode = doc.data()?['currencyCode'] as String?;

      if (cloudCode != null && _allowedCurrencies.contains(cloudCode)) {
        if (cloudCode != state.currencyCode) {
          emit(state.copyWith(currencyCode: cloudCode));
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_currencyKey, cloudCode);
        }
      } else {
        await _writeToCloud(state.currencyCode);
      }
    } catch (_) {
      // Silencieux : on garde la devise locale.
    }
  }

  Future<void> setCurrencyCode(String currencyCode) async {
    if (!_allowedCurrencies.contains(currencyCode)) return;
    emit(state.copyWith(currencyCode: currencyCode, errorMessage: null));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currencyKey, currencyCode);
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Impossible d’enregistrer la devise.'));
    }
    await _writeToCloud(currencyCode);
  }

  Future<void> _writeToCloud(String currencyCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'currencyCode': currencyCode}, SetOptions(merge: true));
    } catch (_) {
      // Silencieux : la devise reste en local.
    }
  }

  static List<String> supportedCurrencies() =>
      _allowedCurrencies.toList()..sort();
}

