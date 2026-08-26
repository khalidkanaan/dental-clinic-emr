import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dental_clinic/core/providers.dart';
import 'package:dental_clinic/features/health/data/health_repository.dart';

/// Runs the connection test once on build and re-runs on demand.
class HealthController extends AsyncNotifier<HealthStatus> {
  @override
  Future<HealthStatus> build() {
    return ref.read(healthRepositoryProvider).check();
  }

  Future<void> retest() async {
    state = const AsyncLoading<HealthStatus>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(healthRepositoryProvider).check(),
    );
  }
}

final healthControllerProvider =
    AsyncNotifierProvider<HealthController, HealthStatus>(HealthController.new);
