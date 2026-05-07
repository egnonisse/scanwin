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
  static const _allowedCurrencies = {'EUR', 'USD', 'GBP', 'CHF'};

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_currencyKey);
      if (stored != null && _allowedCurrencies.contains(stored)) {
        emit(state.copyWith(currencyCode: stored, isLoading: false));
        return;
      }
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Impossible de charger les réglages.',
        ),
      );
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
  }

  static List<String> supportedCurrencies() =>
      _allowedCurrencies.toList()..sort();
}

