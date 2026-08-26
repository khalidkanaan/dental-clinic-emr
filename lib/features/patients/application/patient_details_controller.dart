import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dental_clinic/core/config/app_config.dart';
import 'package:dental_clinic/core/providers.dart';
import 'package:dental_clinic/features/patients/data/patient.dart';
import 'package:dental_clinic/features/visits/data/visit.dart';

class PatientDetailsState {
  const PatientDetailsState({
    required this.patient,
    required this.visits,
    required this.visitsCursor,
    required this.loadingMoreVisits,
    required this.hasMoreVisits,
  });

  final Patient patient;
  final List<Visit> visits;
  final String? visitsCursor;
  final bool loadingMoreVisits;
  final bool hasMoreVisits;

  PatientDetailsState copyWith({
    Patient? patient,
    List<Visit>? visits,
    Object? visitsCursor = _unset,
    bool? loadingMoreVisits,
    bool? hasMoreVisits,
  }) {
    return PatientDetailsState(
      patient: patient ?? this.patient,
      visits: visits ?? this.visits,
      visitsCursor:
          visitsCursor == _unset ? this.visitsCursor : visitsCursor as String?,
      loadingMoreVisits: loadingMoreVisits ?? this.loadingMoreVisits,
      hasMoreVisits: hasMoreVisits ?? this.hasMoreVisits,
    );
  }

  static const Object _unset = Object();
}

class PatientDetailsController
    extends FamilyAsyncNotifier<PatientDetailsState, String> {
  @override
  Future<PatientDetailsState> build(String patientId) async {
    final result =
        await ref.read(patientRepositoryProvider).getWithVisits(patientId);
    return PatientDetailsState(
      patient: result.patient,
      visits: result.visits,
      visitsCursor: result.nextVisitsCursor,
      loadingMoreVisits: false,
      hasMoreVisits:
          result.nextVisitsCursor != null && result.nextVisitsCursor!.isNotEmpty,
    );
  }

  PatientDetailsState get _current => state.value!;

  Future<void> reload() async {
    state = const AsyncLoading<PatientDetailsState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => build(arg));
  }

  Future<void> loadMoreVisits() async {
    if (!state.hasValue) return;
    final current = _current;
    if (current.loadingMoreVisits || !current.hasMoreVisits) return;

    state = AsyncData(current.copyWith(loadingMoreVisits: true));
    final page = await ref.read(visitRepositoryProvider).list(
          arg,
          limit: AppConfig.pageSize,
          cursor: current.visitsCursor,
        );
    state = AsyncData(
      _current.copyWith(
        loadingMoreVisits: false,
        visits: [..._current.visits, ...page.items],
        visitsCursor: page.nextCursor,
        hasMoreVisits: page.hasMore,
      ),
    );
  }

  Future<Visit> addVisit(VisitInput input, {required String idempotencyKey}) async {
    final visit = await ref.read(visitRepositoryProvider).add(
          arg,
          input,
          idempotencyKey: idempotencyKey,
        );
    final visits = [..._current.visits, visit]..sort(_byDateDesc);
    state = AsyncData(_current.copyWith(visits: visits));
    return visit;
  }

  Future<Visit> editVisit(
    String visitId, {
    required String version,
    required VisitInput input,
  }) async {
    final updated = await ref.read(visitRepositoryProvider).update(
          arg,
          visitId,
          version: version,
          input: input,
        );
    final visits = _current.visits
        .map((v) => v.id == visitId ? updated : v)
        .toList()
      ..sort(_byDateDesc);
    state = AsyncData(_current.copyWith(visits: visits));
    return updated;
  }

  Future<void> deleteVisit(String visitId, {required String version}) async {
    await ref.read(visitRepositoryProvider).delete(
          arg,
          visitId,
          version: version,
        );
    state = AsyncData(
      _current.copyWith(
        visits: _current.visits.where((v) => v.id != visitId).toList(),
      ),
    );
  }

  Future<Patient> editPatient({String? name, String? phoneNumber}) async {
    final updated = await ref.read(patientRepositoryProvider).update(
          id: arg,
          version: _current.patient.version,
          name: name,
          phoneNumber: phoneNumber,
        );
    state = AsyncData(_current.copyWith(patient: updated));
    return updated;
  }

  Future<Patient> archive() async {
    final updated = await ref.read(patientRepositoryProvider).archive(
          id: arg,
          version: _current.patient.version,
        );
    state = AsyncData(_current.copyWith(patient: updated));
    return updated;
  }

  Future<Patient> restore() async {
    final updated = await ref.read(patientRepositoryProvider).restore(
          id: arg,
          version: _current.patient.version,
        );
    state = AsyncData(_current.copyWith(patient: updated));
    return updated;
  }

  Future<void> purge() async {
    await ref.read(patientRepositoryProvider).purge(
          id: arg,
          version: _current.patient.version,
        );
  }

  /// Replaces the patient in state (used after an external edit).
  void setPatient(Patient patient) {
    if (!state.hasValue) return;
    state = AsyncData(_current.copyWith(patient: patient));
  }

  static int _byDateDesc(Visit a, Visit b) => b.visitDate.compareTo(a.visitDate);
}

final patientDetailsControllerProvider = AsyncNotifierProvider.family<
    PatientDetailsController, PatientDetailsState, String>(
  PatientDetailsController.new,
);
