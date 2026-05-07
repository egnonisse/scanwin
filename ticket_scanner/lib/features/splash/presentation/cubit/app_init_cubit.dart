import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../firebase_options.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import 'app_init_state.dart';

class AppInitCubit extends Cubit<AppInitState> {
  AppInitCubit({required SettingsCubit settingsCubit})
      : _settingsCubit = settingsCubit,
        super(const AppInitState.initial());

  final SettingsCubit _settingsCubit;

  Future<void> init() async {
    emit(state.copyWith(status: AppInitStatus.loading, errorMessage: null));

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }

      final user = auth.currentUser;
      if (user == null) {
        throw StateError('Utilisateur Firebase absent après authentification.');
      }

      final users = FirebaseFirestore.instance.collection('users');
      final userRef = users.doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snapshot = await tx.get(userRef);
        if (!snapshot.exists) {
          tx.set(userRef, {
            'points': 0,
            'currencyCode': _settingsCubit.state.currencyCode,
            'createdAt': FieldValue.serverTimestamp(),
          });
          return;
        }

        final data = snapshot.data() ?? <String, dynamic>{};
        if (!data.containsKey('currencyCode')) {
          tx.update(userRef, {'currencyCode': _settingsCubit.state.currencyCode});
        }
        if (!data.containsKey('points')) {
          tx.update(userRef, {'points': 0});
        }
      });

      emit(state.copyWith(status: AppInitStatus.ready));
    } catch (e) {
      emit(
        state.copyWith(
          status: AppInitStatus.error,
          errorMessage:
              'Initialisation Firebase impossible. Vérifie la configuration (FlutterFire) puis relance.\n\nDétail: $e',
        ),
      );
    }
  }
}

