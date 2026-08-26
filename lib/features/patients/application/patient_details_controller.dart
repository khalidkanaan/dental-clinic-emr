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

/// Loads and mutates the details for one patient.
///
/// Riverpod 3 removed `FamilyAsyncNotifier`. Family arguments are passed to
/// the notifier constructor instead, so this class extends `AsyncNotifier` and
/// stores [patientId] directly.
class PatientDetailsController extends AsyncNotifier<PatientDetailsState> {
  PatientDetailsController(this.patientId);

  final String patientId;

  @override
  Future<PatientDetailsState> build() => _fetchPatientDetails();

  PatientDetailsState get _current => state.requireValue;

  Future<PatientDetailsState> _fetchPatientDetails() async {
    final result =
        await ref.read(patientRepositoryProvider).getWithVisits(patientId);

    return PatientDetailsState(
      patient: result.patient,
      visits: result.visits,
      visitsCursor: result.nextVisitsCursor,
      loadingMoreVisits: false,
      hasMoreVisits: result.nextVisitsCursor != null &&
          result.nextVisitsCursor!.isNotEmpty,
    );
  }

  Future<void> reload() async {
    // `copyWithPrevious` is an internal Riverpod API in Riverpod 3, so avoid it.
    state = const AsyncLoading<PatientDetailsState>();
    state = await AsyncValue.guard(_fetchPatientDetails);
  }

  Future<void> loadMoreVisits() async {
    if (!state.hasValue) return;

    final current = _current;
    if (current.loadingMoreVisits || !current.hasMoreVisits) return;

    state = AsyncData(current.copyWith(loadingMoreVisits: true));

    try {
      final page = await ref.read(visitRepositoryProvider).list(
            patientId,
            limit: AppConfig.pageSize,
            cursor: current.visitsCursor,
          );

      // Use the latest state in case another operation updated the patient or
      // visit list while the page request was in flight.
      final latest = state.hasValue ? _current : current;

      state = AsyncData(
        latest.copyWith(
          loadingMoreVisits: false,
          visits: [...latest.visits, ...page.items],
          visitsCursor: page.nextCursor,
          hasMoreVisits: page.hasMore,
        ),
      );
    } catch (_) {
      // Do not leave the pagination spinner stuck on if the request fails.
      if (state.hasValue) {
        state = AsyncData(_current.copyWith(loadingMoreVisits: false));
      }
      rethrow;
    }
  }

  Future<Visit> addVisit(
    VisitInput input, {
    required String idempotencyKey,
  }) async {
    final visit = await ref.read(visitRepositoryProvider).add(
          patientId,
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
          patientId,
          visitId,
          version: version,
          input: input,
        );

    final visits = _current.visits
        .map((visit) => visit.id == visitId ? updated : visit)
        .toList()
      ..sort(_byDateDesc);

    state = AsyncData(_current.copyWith(visits: visits));
    return updated;
  }

  Future<void> deleteVisit(
    String visitId, {
    required String version,
  }) async {
    await ref.read(visitRepositoryProvider).delete(
          patientId,
          visitId,
          version: version,
        );

    state = AsyncData(
      _current.copyWith(
        visits: _current.visits.where((visit) => visit.id != visitId).toList(),
      ),
    );
  }

  Future<Patient> editPatient({
    String? name,
    String? phoneNumber,
  }) async {
    final updated = await ref.read(patientRepositoryProvider).update(
          id: patientId,
          version: _current.patient.version,
          name: name,
          phoneNumber: phoneNumber,
        );

    state = AsyncData(_current.copyWith(patient: updated));
    return updated;
  }

  Future<Patient> archive() async {
    final updated = await ref.read(patientRepositoryProvider).archive(
          id: patientId,
          version: _current.patient.version,
        );

    state = AsyncData(_current.copyWith(patient: updated));
    return updated;
  }

  Future<Patient> restore() async {
    final updated = await ref.read(patientRepositoryProvider).restore(
          id: patientId,
          version: _current.patient.version,
        );

    state = AsyncData(_current.copyWith(patient: updated));
    return updated;
  }

  Future<void> purge() async {
    await ref.read(patientRepositoryProvider).purge(
          id: patientId,
          version: _current.patient.version,
        );
  }

  /// Replaces the patient in state (used after an external edit).
  void setPatient(Patient patient) {
    if (!state.hasValue) return;
    state = AsyncData(_current.copyWith(patient: patient));
  }

  static int _byDateDesc(Visit a, Visit b) =>
      b.visitDate.compareTo(a.visitDate);
}

final patientDetailsControllerProvider = AsyncNotifierProvider.family<
    PatientDetailsController,
    PatientDetailsState,
    String>(
  PatientDetailsController.new,
);
