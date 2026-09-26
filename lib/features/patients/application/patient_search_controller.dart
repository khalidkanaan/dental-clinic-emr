import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dental_clinic/core/config/app_config.dart';
import 'package:dental_clinic/core/error/api_exception.dart';
import 'package:dental_clinic/core/providers.dart';
import 'package:dental_clinic/features/patients/data/patient.dart';
import 'package:dental_clinic/features/patients/domain/patient_filters.dart';

const Object _noValue = Object();

class PatientSearchState {
  const PatientSearchState({
    required this.query,
    required this.filters,
    required this.patients,
    required this.cursor,
    required this.initialLoading,
    required this.loadingMore,
    required this.hasMore,
    required this.error,
  });

  const PatientSearchState.initial()
      : query = '',
        filters = PatientFilters.none,
        patients = const [],
        cursor = null,
        initialLoading = true,
        loadingMore = false,
        hasMore = false,
        error = null;

  final String query;

  /// Filters applied on top of [query]. Persisted across launches.
  final PatientFilters filters;
  final List<Patient> patients;
  final String? cursor;
  final bool initialLoading;
  final bool loadingMore;
  final bool hasMore;
  final ApiException? error;

  bool get includeArchived => filters.includeArchived;

  bool get hasQuery => query.trim().isNotEmpty;

  bool get isEmpty =>
      !initialLoading && error == null && patients.isEmpty;

  PatientSearchState copyWith({
    String? query,
    PatientFilters? filters,
    List<Patient>? patients,
    Object? cursor = _noValue,
    bool? initialLoading,
    bool? loadingMore,
    bool? hasMore,
    Object? error = _noValue,
  }) {
    return PatientSearchState(
      query: query ?? this.query,
      filters: filters ?? this.filters,
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

  /// The day relative filters were resolved against for the current search,
  /// reused by [loadMore] so every page of one search uses the same dates.
  DateTime _searchDay = DateTime.now();

  /// Set once the user changes filters, so the saved filters loading at
  /// startup never overwrite a choice made in the meantime.
  bool _filtersTouched = false;

  @override
  PatientSearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    Future.microtask(_restoreFiltersAndSearch);
    return const PatientSearchState.initial();
  }

  /// Loads the filters saved from the last session, then runs the first
  /// search with them (one request instead of an unfiltered one followed by a
  /// filtered one).
  Future<void> _restoreFiltersAndSearch() async {
    final saved = await _loadSavedFilters();
    if (!_filtersTouched && saved != state.filters) {
      state = state.copyWith(filters: saved);
    }
    await _runSearch();
  }

  Future<PatientFilters> _loadSavedFilters() async {
    try {
      final raw = await ref.read(appPreferencesProvider).readPatientFilters();
      if (raw == null || raw.isEmpty) return PatientFilters.none;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return PatientFilters.none;
      return PatientFilters.fromJson(decoded.cast<String, Object?>());
    } catch (e) {
      // A corrupt value must never block the directory; start unfiltered.
      debugPrint('Ignoring saved patient filters: $e');
      return PatientFilters.none;
    }
  }

  Future<void> _saveFilters(PatientFilters filters) async {
    try {
      await ref.read(appPreferencesProvider).writePatientFilters(
            filters.isActive ? jsonEncode(filters.toJson()) : null,
          );
    } catch (e) {
      debugPrint('Could not save patient filters: $e');
    }
  }

  /// Called on every keystroke; the actual request is debounced.
  void onQueryChanged(String query) {
    state = state.copyWith(query: query);
    _debounce?.cancel();
    _debounce = Timer(AppConfig.searchDebounce, _runSearch);
  }

  /// Replaces the filters, saves them and reloads the list. The current
  /// search text is kept, so both apply together.
  void applyFilters(PatientFilters filters) {
    _filtersTouched = true;
    if (filters == state.filters) return;
    state = state.copyWith(filters: filters);
    unawaited(_saveFilters(filters));
    _debounce?.cancel();
    _runSearch();
  }

  /// Switches off a single filter (e.g. from its chip).
  void removeFilter(PatientFilterKind kind) =>
      applyFilters(state.filters.without(kind));

  void clearFilters() => applyFilters(PatientFilters.none);

  void setIncludeArchived(bool value) =>
      applyFilters(state.filters.copyWith(includeArchived: value));

  Future<void> refresh() => _runSearch();

  Future<void> _runSearch() async {
    final seq = ++_seq;
    _searchDay = DateTime.now();
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
            filters: state.filters,
            contains: true,
            limit: AppConfig.pageSize,
            today: _searchDay,
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
            filters: state.filters,
            contains: true,
            limit: AppConfig.pageSize,
            cursor: state.cursor,
            today: _searchDay,
          );
      if (seq != _seq) return;
      // A patient edited while this list was open may already have been
      // inserted at the top (see applyPatientChange); don't show them twice.
      final shown = {for (final p in state.patients) p.id};
      state = state.copyWith(
        loadingMore: false,
        patients: [
          ...state.patients,
          ...page.items.where((p) => !shown.contains(p.id)),
        ],
        cursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    } on ApiException catch (e) {
      if (seq != _seq) return;
      state = state.copyWith(loadingMore: false, error: e);
    }
  }

  /// Reflects an edited/created/archived/restored patient in the visible list
  /// without a full reload. A patient that no longer matches the active
  /// filters is removed; one that newly matches is added at the top.
  void applyPatientChange(Patient patient) {
    final index = state.patients.indexWhere((p) => p.id == patient.id);
    final matchesFilters = state.filters.matches(patient, DateTime.now());
    // Patients already listed were matched by the server; only a patient
    // being added needs a (simplified) check against the search text.
    final belongsInList =
        matchesFilters && (index >= 0 || _roughlyMatchesQuery(patient));
    final next = [...state.patients];
    if (belongsInList) {
      if (index >= 0) {
        next[index] = patient;
      } else {
        next.insert(0, patient);
      }
    } else if (index >= 0) {
      next.removeAt(index);
    } else {
      return; // Not shown and should not be: nothing to do.
    }
    state = state.copyWith(patients: next);
  }

  /// Approximation of the server's name/phone search, used only to decide
  /// whether to insert a patient that is not already in the results. The
  /// next refresh corrects any edge cases (e.g. Arabic letter variants).
  bool _roughlyMatchesQuery(Patient patient) {
    final query = state.query.trim().toLowerCase();
    if (query.isEmpty) return true;
    if (patient.name.toLowerCase().contains(query)) return true;
    final digits = query.replaceAll(RegExp(r'\D'), '');
    return digits.isNotEmpty &&
        patient.phoneNumber.replaceAll(RegExp(r'\D'), '').contains(digits);
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
