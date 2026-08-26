import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dental_clinic/features/patients/data/patient.dart';
import 'package:dental_clinic/features/patients/presentation/patient_details_screen.dart';
import 'package:dental_clinic/features/patients/presentation/patient_directory_screen.dart';
import 'package:dental_clinic/features/patients/presentation/patient_form_screen.dart';
import 'package:dental_clinic/features/settings/presentation/settings_screen.dart';
import 'package:dental_clinic/features/setup/application/auth_controller.dart';
import 'package:dental_clinic/features/setup/presentation/setup_screen.dart';
import 'package:dental_clinic/features/setup/presentation/splash_screen.dart';
import 'package:dental_clinic/features/visits/data/visit.dart';
import 'package:dental_clinic/features/visits/presentation/visit_form_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => refresh.value = next);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      if (auth.isLoading) {
        return loc == '/splash' ? null : '/splash';
      }
      if (!auth.hasToken) {
        return loc == '/setup' ? null : '/setup';
      }
      if (loc == '/splash' || loc == '/setup') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const PatientDirectoryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/patient/new',
        builder: (context, state) => const PatientFormScreen(),
      ),
      GoRoute(
        path: '/patient/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra;
          final autoRestore =
              extra is Map && extra['autoRestore'] == true;
          return PatientDetailsScreen(patientId: id, autoRestore: autoRestore);
        },
      ),
      GoRoute(
        path: '/patient/:id/edit',
        builder: (context, state) =>
            PatientFormScreen(patient: state.extra as Patient?),
      ),
      GoRoute(
        path: '/patient/:id/visit/new',
        builder: (context, state) =>
            VisitFormScreen(patientId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/patient/:id/visit/edit',
        builder: (context, state) => VisitFormScreen(
          patientId: state.pathParameters['id']!,
          visit: state.extra as Visit?,
        ),
      ),
    ],
  );
});
