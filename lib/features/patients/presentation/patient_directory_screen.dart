import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:dental_clinic/core/widgets/empty_state.dart';
import 'package:dental_clinic/core/widgets/error_view.dart';
import 'package:dental_clinic/core/widgets/max_width.dart';
import 'package:dental_clinic/core/widgets/clinic_logo.dart';
import 'package:dental_clinic/features/patients/application/patient_search_controller.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(patientSearchControllerProvider);
    final controller = ref.read(patientSearchControllerProvider.notifier);

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
              TextField(
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
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilterChip(
                  label: Text(l10n.showArchived),
                  selected: state.includeArchived,
                  onSelected: controller.setIncludeArchived,
                  showCheckmark: false,
                  avatar: Icon(
                    state.includeArchived
                        ? Icons.inventory_2_rounded
                        : Icons.inventory_2_outlined,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 4),
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
      final searching = state.query.trim().isNotEmpty;
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
