import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:dental_clinic/core/widgets/empty_state.dart';
import 'package:dental_clinic/core/widgets/error_view.dart';
import 'package:dental_clinic/core/widgets/max_width.dart';
import 'package:dental_clinic/core/widgets/clinic_logo.dart';
import 'package:dental_clinic/features/patients/application/patient_search_controller.dart';
import 'package:dental_clinic/features/patients/presentation/widgets/active_filters_bar.dart';
import 'package:dental_clinic/features/patients/presentation/widgets/patient_filter_sheet.dart';
import 'package:dental_clinic/features/patients/presentation/widgets/patient_list_tile.dart';
import 'package:dental_clinic/l10n/app_localizations.dart';

class PatientDirectoryScreen extends ConsumerStatefulWidget {
  const PatientDirectoryScreen({super.key});

  @override
  ConsumerState<PatientDirectoryScreen> createState() =>
      _PatientDirectoryScreenState();
}

class _PatientDirectoryScreenState
    extends ConsumerState<PatientDirectoryScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _filterSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(patientSearchControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _openFilters() async {
    if (_filterSheetOpen) return; // ignore double taps
    _filterSheetOpen = true;
    try {
      final controller = ref.read(patientSearchControllerProvider.notifier);
      final current = ref.read(patientSearchControllerProvider).filters;
      final result = await showPatientFilterSheet(context, initial: current);
      if (result != null) controller.applyFilters(result);
    } finally {
      _filterSheetOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(patientSearchControllerProvider);
    final controller = ref.read(patientSearchControllerProvider.notifier);
    final filters = state.filters;

    return Scaffold(
      appBar: AppBar(
        title: ClinicLogo(semanticLabel: l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/patient/new'),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(l10n.newPatient),
      ),
      body: SafeArea(
        child: MaxWidth(
          maxWidth: 1000,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: controller.onQueryChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: l10n.searchHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: state.query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  controller.onQueryChanged('');
                                },
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FilterButton(
                    activeCount: filters.activeCount,
                    onPressed: _openFilters,
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: filters.isActive
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: ActiveFiltersBar(
                          filters: filters,
                          onRemove: controller.removeFilter,
                          onClearAll: controller.clearFilters,
                          onEdit: _openFilters,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildResults(context, state, controller)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    PatientSearchState state,
    PatientSearchController controller,
  ) {
    final l10n = AppLocalizations.of(context);

    if (state.initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return ErrorView(error: state.error!, onRetry: controller.refresh);
    }
    if (state.isEmpty) {
      final searching = state.hasQuery;
      final filtering = state.filters.isActive;

      if (filtering) {
        return EmptyState(
          icon: Icons.filter_alt_off_rounded,
          title: l10n.emptyNoResultsTitle,
          message: searching
              ? l10n.emptyNoSearchAndFilterMatchesBody
              : l10n.emptyNoFilterMatchesBody,
          action: FilledButton.tonalIcon(
            onPressed: controller.clearFilters,
            icon: const Icon(Icons.filter_alt_off_rounded),
            label: Text(l10n.actionClearFilters),
          ),
        );
      }

      return EmptyState(
        icon: searching ? Icons.search_off_rounded : Icons.people_outline_rounded,
        title: searching ? l10n.emptyNoResultsTitle : l10n.emptyNoPatientsTitle,
        message: searching ? l10n.emptyNoResultsBody : l10n.emptyNoPatientsBody,
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 96, top: 4),
        itemCount: state.patients.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.patients.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final patient = state.patients[index];
          return PatientListTile(
            patient: patient,
            onTap: () => context.push('/patient/${patient.id}'),
          );
        },
      ),
    );
  }
}

/// Square button beside the search field that opens the filter panel.
///
/// Matches the search field's height and shape. When filters are active it
/// switches to the primary tint and shows how many are applied.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.activeCount, required this.onPressed});

  /// Same height as the themed search field (14 + 24 + 14).
  static const double _size = 52;

  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final active = activeCount > 0;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: active ? scheme.primary : scheme.outlineVariant,
        width: active ? 1.6 : 1,
      ),
    );

    // One merged node for screen readers: the name, how many filters are on,
    // and the tap action (the tooltip is for mouse/long-press users).
    return Semantics(
      button: true,
      label: active
          ? '${l10n.filtersButtonTooltip}, ${l10n.filtersActiveCount(activeCount)}'
          : l10n.filtersButtonTooltip,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: l10n.filtersButtonTooltip,
        child: SizedBox.square(
          dimension: _size,
          child: Material(
            color: active
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              customBorder: shape,
              child: Center(
                child: Badge(
                  isLabelVisible: active,
                  label: Text('$activeCount'),
                  backgroundColor: scheme.primary,
                  textColor: scheme.onPrimary,
                  child: Icon(
                    Icons.tune_rounded,
                    color: active
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
