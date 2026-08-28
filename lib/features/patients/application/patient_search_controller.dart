import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dental_clinic/core/config/app_config.dart';
import 'package:dental_clinic/core/error/api_exception.dart';
import 'package:dental_clinic/core/providers.dart';
import 'package:dental_clinic/features/patients/data/patient.dart';

const Object _noValue = Object();

class PatientSearchState {
  const PatientSearchState({
    required this.query,
    required this.includeArchived,
    required this.patients,
    required this.cursor,
    required this.initialLoading,
    required this.loadingMore,
    required this.hasMore,
    required this.error,
  });

  const PatientSearchState.initial()
      : query = '',
        includeArchived = false,
        patients = const [],
        cursor = null,
        initialLoading = true,
        loadingMore = false,
        hasMore = false,
        error = null;

  final String query;
  final bool includeArchived;
  final List<Patient> patients;
  final String? cursor;
  final bool initialLoading;
  final bool loadingMore;
  final bool hasMore;
  final ApiException? error;

  bool get isEmpty =>
      !initialLoading && error == null && patients.isEmpty;

  PatientSearchState copyWith({
    String? query,
    bool? includeArchived,
    List<Patient>? patients,
    Object? cursor = _noValue,
    bool? initialLoading,
    bool? loadingMore,
    bool? hasMore,
    Object? error = _noValue,
  }) {
    return PatientSearchState(
      query: query ?? this.query,
      includeArchived: includeArchived ?? this.includeArchived,
      patients: patients ?? this.patients,
      cursor: cursor == _noValue ? this.cursor : cursor as String?,
      initialLoading: initialLoading ?? this.initialLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error == _noValue ? this.error : error as ApiException?,
    );
  }
}

class PatientSearchController extends Notifier<PatientSearchState> {
  Timer? _debounce;
  int _seq = 0;

  @override
  PatientSearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    Future.microtask(_runSearch);
    return const PatientSearchState.initial();
  }

  /// Called on every keystroke; the actual request is debounced.
  void onQueryChanged(String query) {
    state = state.copyWith(query: query);
    _debounce?.cancel();
    _debounce = Timer(AppConfig.searchDebounce, _runSearch);
  }

  void setIncludeArchived(bool value) {
    if (value == state.includeArchived) return;
    state = state.copyWith(includeArchived: value);
    _runSearch();
  }

  Future<void> refresh() => _runSearch();

  Future<void> _runSearch() async {
    final seq = ++_seq;
    state = state.copyWith(
      initialLoading: true,
      loadingMore: false,
      error: null,
      patients: const [],
      cursor: null,
      hasMore: false,
    );
    try {
      final page = await ref.read(patientRepositoryProvider).search(
            query: state.query.trim(),
            includeArchived: state.includeArchived,
            contains: true,
            limit: AppConfig.pageSize,
          );
      if (seq != _seq) return; // superseded by a newer search
      state = state.copyWith(
        initialLoading: false,
        patients: page.items,
        cursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    } on ApiException catch (e) {
      if (seq != _seq) return;
      state = state.copyWith(initialLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore || state.initialLoading) return;
    final seq = _seq;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await ref.read(patientRepositoryProvider).search(
            query: state.query.trim(),
            includeArchived: state.includeArchived,
            contains: true,
            limit: AppConfig.pageSize,
            cursor: state.cursor,
          );
      if (seq != _seq) return;
      state = state.copyWith(
        loadingMore: false,
        patients: [...state.patients, ...page.items],
        cursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    } on ApiException catch (e) {
      if (seq != _seq) return;
      state = state.copyWith(loadingMore: false, error: e);
    }
  }

  /// Reflects an edited/created/archived/restored patient in the visible list
  /// without a full reload.
  void applyPatientChange(Patient patient) {
    final showArchived = state.includeArchived;
    final belongsInList = showArchived || !patient.isArchived;
    final index = state.patients.indexWhere((p) => p.id == patient.id);
    final next = [...state.patients];
    if (belongsInList) {
      if (index >= 0) {
        next[index] = patient;
      } else {
        next.insert(0, patient);
      }
    } else if (index >= 0) {
      next.removeAt(index);
    }
    state = state.copyWith(patients: next);
  }

  void removePatient(String id) {
    state = state.copyWith(
      patients: state.patients.where((p) => p.id != id).toList(),
    );
  }
}

final patientSearchControllerProvider =
    NotifierProvider<PatientSearchController, PatientSearchState>(
  PatientSearchController.new,
);
