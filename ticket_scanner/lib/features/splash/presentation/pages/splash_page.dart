import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../cubit/app_init_cubit.dart';
import '../cubit/app_init_state.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AppInitCubit(settingsCubit: context.read<SettingsCubit>())
        ..init(),
      child: BlocListener<AppInitCubit, AppInitState>(
        listenWhen: (previous, current) =>
            previous.status != current.status &&
            current.status == AppInitStatus.ready,
        listener: (context, state) => context.go('/home'),
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: BlocBuilder<AppInitCubit, AppInitState>(
                  builder: (context, state) {
                    if (state.status == AppInitStatus.error) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Erreur au démarrage',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            state.errorMessage ?? 'Erreur inconnue',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () =>
                                context.read<AppInitCubit>().init(),
                            child: const Text('Réessayer'),
                          ),
                        ],
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Initialisation…',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

