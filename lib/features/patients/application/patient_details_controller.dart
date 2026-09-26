import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:dental_clinic/core/config/app_config.dart';
import 'package:dental_clinic/core/error/api_exception.dart';
import 'package:dental_clinic/core/providers.dart';
import 'package:dental_clinic/features/patients/application/patient_search_controller.dart';
import 'package:dental_clinic/features/patients/data/patient.dart';
import 'package:dental_clinic/features/settings/application/settings_controllers.dart';
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

  /// Held while this patient should stay in memory after their screen closes.
  KeepAliveLink? _keepAlive;

  @override
  Future<PatientDetailsState> build() {
    _keepAlive = null;
    _applyCaching(ref.read(alwaysLoadLatestPatientProvider));
    ref.listen<bool>(alwaysLoadLatestPatientProvider, (_, next) {
      _applyCaching(next);
    });
    return _fetchPatientDetails();
  }

  /// With "Always load the latest patient record" on, the patient is dropped
  /// as soon as nothing shows them, so opening them again loads from the
  /// server. With it off, they stay in memory until refreshed.
  void _applyCaching(bool alwaysLoadLatest) {
    if (alwaysLoadLatest) {
      _keepAlive?.close();
      _keepAlive = null;
    } else {
      _keepAlive ??= ref.keepAlive();
    }
  }

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

  /// Fetches the latest patient and first page of visits while the current
  /// ones stay on screen (no loading spinner), so changes made on another
  /// device appear. Used by the patient page's refresh button, F5 and
  /// pull-down.
  ///
  /// Returns null on success, or the error (what's shown is then left as it
  /// was). If the patient hasn't loaded yet, does a full load instead.
  Future<ApiException?> refresh() async {
    if (!state.hasValue) {
      await reload();
      final error = state.error;
      if (error == null) return null;
      return error is ApiException
          ? error
          : const ApiException(code: ApiErrorCode.unknown);
    }

    final before = state.value;
    try {
      final fresh = await _fetchPatientDetails();
      // Anything that changed the state while we were fetching (a visit
      // saved here, more visits loaded) wins; don't replace it with a
      // response that may predate it.
      if (!identical(state.value, before)) return null;
      state = AsyncData(fresh);
      return null;
    } on ApiException catch (e) {
      return e;
    }
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
    final result = await ref.read(visitRepositoryProvider).add(
          patientId,
          input,
          idempotencyKey: idempotencyKey,
        );

    final visits = [..._current.visits, result.visit]..sort(_byDateDesc);
    state = AsyncData(_current.copyWith(visits: visits));
    _applyServerPatient(result.patient);
    return result.visit;
  }

  Future<Visit> editVisit(
    String visitId, {
    required String version,
    required VisitInput input,
  }) async {
    final result = await ref.read(visitRepositoryProvider).update(
          patientId,
          visitId,
          version: version,
          input: input,
        );

    final visits = _current.visits
        .map((visit) => visit.id == visitId ? result.visit : visit)
        .toList()
      ..sort(_byDateDesc);

    state = AsyncData(_current.copyWith(visits: visits));
    _applyServerPatient(result.patient);
    return result.visit;
  }

  Future<void> deleteVisit(
    String visitId, {
    required String version,
  }) async {
    final patient = await ref.read(visitRepositoryProvider).delete(
          patientId,
          visitId,
          version: version,
        );

    state = AsyncData(
      _current.copyWith(
        visits: _current.visits.where((visit) => visit.id != visitId).toList(),
      ),
    );
    _applyServerPatient(patient);
  }

  /// Visit changes update the patient on the server (last visit date, amount
  /// owed, version). Adopt the returned copy here and in the directory so a
  /// later edit/archive/credit change uses the current version, and so the
  /// directory filters see the new last visit date and balance.
  void _applyServerPatient(Patient? patient) {
    if (patient == null || !state.hasValue) return;
    state = AsyncData(_current.copyWith(patient: patient));
    ref.read(patientSearchControllerProvider.notifier).applyPatientChange(patient);
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

  /// Sets the patient's credit balance to [credit] (hundredths of JOD, >= 0).
  ///
  /// The patient record can change underneath us (for example a visit added
  /// on another device updates its last visit date and version). If the save
  /// hits a version conflict, the latest patient is fetched: when its credit
  /// is still the value the user was looking at, the save is retried once
  /// with the fresh version. If the credit itself was changed elsewhere, the
  /// fresh patient is put into state (so the sheet shows the real history)
  /// and the conflict is rethrown.
  Future<Patient> updateCredit(int credit) async {
    if (credit < 0) {
      throw const ApiException(code: ApiErrorCode.validationError);
    }

    final repo = ref.read(patientRepositoryProvider);
    final seen = _current.patient;

    Patient updated;
    try {
      updated = await repo.update(
        id: patientId,
        version: seen.version,
        credit: credit,
      );
    } on ApiException catch (e) {
      if (!e.isVersionConflict) rethrow;

      final fresh = await repo.get(patientId);
      if (state.hasValue) {
        state = AsyncData(_current.copyWith(patient: fresh));
      }
      if (fresh.credit != seen.credit || fresh.isArchived) rethrow;

      updated = await repo.update(
        id: patientId,
        version: fresh.version,
        credit: credit,
      );
    }

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

/// Auto-disposed, but kept in memory unless "Always load the latest patient
/// record" is on (see [PatientDetailsController._applyCaching]).
final patientDetailsControllerProvider = AsyncNotifierProvider.autoDispose
    .family<PatientDetailsController, PatientDetailsState, String>(
  PatientDetailsController.new,
);
