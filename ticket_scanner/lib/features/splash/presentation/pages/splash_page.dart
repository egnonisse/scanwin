import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
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
                        Image.asset(
                          'assets/images/logo.png',
                          width: 96,
                          height: 96,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.appBarStart,
                                  AppColors.appBarEnd
                                ],
                              ),
                              borderRadius:
                                  BorderRadius.circular(AppRadii.icon),
                            ),
                            child: const Icon(
                              Icons.local_pharmacy,
                              color: AppColors.onPrimary,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'PharmaScan',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Comparez. Payez juste.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 24),
                        const CircularProgressIndicator(),
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

