import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dental_clinic/core/api/api_client.dart';
import 'package:dental_clinic/core/storage/preferences.dart';
import 'package:dental_clinic/core/storage/secure_storage.dart';
import 'package:dental_clinic/features/health/data/health_repository.dart';
import 'package:dental_clinic/features/patients/data/patient_repository.dart';
import 'package:dental_clinic/features/visits/data/visit_repository.dart';

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

final appPreferencesProvider =
    Provider<AppPreferences>((ref) => AppPreferences());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(store: ref.watch(secureStoreProvider));
});

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  return PatientRepository(ref.watch(apiClientProvider));
});

final visitRepositoryProvider = Provider<VisitRepository>((ref) {
  return VisitRepository(ref.watch(apiClientProvider));
});

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return HealthRepository(ref.watch(apiClientProvider));
});
