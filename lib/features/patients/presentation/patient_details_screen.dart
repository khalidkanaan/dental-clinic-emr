import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dental_clinic/core/error/api_exception.dart';
import 'package:dental_clinic/core/error/error_messages.dart';
import 'package:dental_clinic/core/formatting/currency_formatter.dart';
import 'package:dental_clinic/core/widgets/app_dialogs.dart';
import 'package:dental_clinic/core/widgets/empty_state.dart';
import 'package:dental_clinic/core/widgets/error_view.dart';
import 'package:dental_clinic/core/widgets/patient_avatar.dart';
import 'package:dental_clinic/features/patients/application/patient_details_controller.dart';
import 'package:dental_clinic/features/patients/application/patient_search_controller.dart';
import 'package:dental_clinic/features/patients/data/patient.dart';
import 'package:dental_clinic/features/visits/data/visit.dart';
import 'package:dental_clinic/features/visits/presentation/widgets/visit_card.dart';
import 'package:dental_clinic/l10n/app_localizations.dart';

class PatientDetailsScreen extends ConsumerStatefulWidget {
  const PatientDetailsScreen({
    super.key,
    required this.patientId,
    this.autoRestore = false,
  });

  final String patientId;
  final bool autoRestore;

  @override
  ConsumerState<PatientDetailsScreen> createState() =>
      _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends ConsumerState<PatientDetailsScreen> {
  final _scrollController = ScrollController();
  bool _autoRestoreHandled = false;
  bool _showOwedOnly = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  PatientDetailsController get _controller =>
      ref.read(patientDetailsControllerProvider(widget.patientId).notifier);

  void _onScroll() {
    // The "owed only" view loads its full set up front, so infinite scroll is
    // only needed for the recent-visits list.
    if (_showOwedOnly) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      _controller.loadMoreVisits();
    }
  }

  void _syncDirectory(Patient patient) {
    ref.read(patientSearchControllerProvider.notifier).applyPatientChange(patient);
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    try {
      await action();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isVersionConflict) {
        final reload = await showVersionConflictDialog(context);
        if (reload) await _controller.reload();
        return;
      }
      showAppSnackBar(context, localizedError(l10n, e));
    }
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _archive(Patient patient) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showConfirmDialog(
      context,
      title: l10n.archivePatient,
      message: l10n.archivePatientBody,
      confirmLabel: l10n.archivePatientConfirm,
    );
    if (!ok) return;
    await _runMutation(() async {
      final updated = await _controller.archive();
      _syncDirectory(updated);
      if (mounted) showAppSnackBar(context, l10n.patientArchivedNotice);
    });
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context);
    await _runMutation(() async {
      final updated = await _controller.restore();
      _syncDirectory(updated);
      if (mounted) showAppSnackBar(context, l10n.patientRestoredNotice);
    });
  }

  Future<void> _permanentlyDelete() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showConfirmDialog(
      context,
      title: l10n.permanentlyDeleteTitle,
      message: l10n.permanentlyDeleteBody,
      confirmLabel: l10n.permanentlyDeleteConfirm,
      destructive: true,
    );
    if (!ok) return;
    await _runMutation(() async {
      await _controller.purge();
      ref
          .read(patientSearchControllerProvider.notifier)
          .removePatient(widget.patientId);
      if (mounted) {
        showAppSnackBar(context, l10n.patientDeletedNotice);
        context.pop();
      }
    });
  }

  Future<void> _deleteVisit(Visit visit) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showConfirmDialog(
      context,
      title: l10n.deleteVisitTitle,
      message: l10n.deleteVisitBody,
      confirmLabel: l10n.actionDelete,
      destructive: true,
    );
    if (!ok) return;
    await _runMutation(() async {
      await _controller.deleteVisit(visit.id, version: visit.version);
      if (mounted) showAppSnackBar(context, l10n.visitDeleted);
    });
  }

  void _maybeAutoRestore(Patient patient) {
    if (widget.autoRestore && !_autoRestoreHandled && patient.isArchived) {
      _autoRestoreHandled = true;
      Future.microtask(_restore);
    }
  }

  void _toggleOwedFilter(bool value) {
    setState(() => _showOwedOnly = value);
    // The actual loading is kicked off from build() so it also covers the case
    // where the cache was invalidated by a mutation while the filter is open.
  }

  /// Ensures the full owed-visit set is loaded whenever the filter is showing it
  /// and it isn't already loaded / loading. Safe to call from build(): it only
  /// schedules a microtask and the controller call is idempotent.
  void _maybeLoadOwedVisits(PatientDetailsState state) {
    if (_showOwedOnly &&
        state.owedVisits == null &&
        !state.loadingOwedVisits) {
      Future.microtask(() => _runMutation(_controller.ensureOwedVisitsLoaded));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncState = ref.watch(patientDetailsControllerProvider(widget.patientId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.directoryTitle),
        actions: [
          asyncState.maybeWhen(
            data: (state) => _buildActions(context, state.patient),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: asyncState.maybeWhen(
        data: (state) => state.patient.isArchived
            ? null
            : FloatingActionButton.extended(
                onPressed: () =>
                    context.push('/patient/${widget.patientId}/visit/new'),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.addVisit),
              ),
        orElse: () => null,
      ),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(
            error: error is ApiException
                ? error
                : const ApiException(code: ApiErrorCode.unknown),
            onRetry: _controller.reload,
          ),
          data: (state) {
            _maybeAutoRestore(state.patient);
            _maybeLoadOwedVisits(state);
            return _buildContent(context, state);
          },
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, Patient patient) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!patient.isArchived)
          IconButton(
            tooltip: l10n.actionEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await context.push('/patient/${widget.patientId}/edit',
                  extra: patient);
              // The details controller already reflects the edit; keep the
              // directory in sync with the latest patient.
              final latest = ref.read(patientDetailsControllerProvider(widget.patientId)).value?.patient;
              if (latest != null) _syncDirectory(latest);
            },
          ),
        PopupMenuButton<int>(
          tooltip: l10n.moreActions,
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) {
            switch (value) {
              case 0:
                _archive(patient);
              case 1:
                _restore();
              case 2:
                _permanentlyDelete();
            }
          },
          itemBuilder: (context) => [
            if (!patient.isArchived)
              PopupMenuItem(
                value: 0,
                child: _menuRow(Icons.inventory_2_outlined, l10n.archivePatient),
              ),
            if (patient.isArchived)
              PopupMenuItem(
                value: 1,
                child: _menuRow(Icons.unarchive_outlined, l10n.actionRestorePatient),
              ),
            if (patient.isArchived)
              PopupMenuItem(
                value: 2,
                child: _menuRow(
                  Icons.delete_forever_outlined,
                  l10n.permanentlyDelete,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _menuRow(IconData icon, String label, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: color == null ? null : TextStyle(color: color)),
      ],
    );
  }

  Widget _buildContent(BuildContext context, PatientDetailsState state) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Frozen patient information. Stays pinned at the top while the
            // visit history below scrolls.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: _PatientHeader(
                    patient: state.patient,
                    onCall: () => _callPhone(state.patient.phoneNumber),
                  ),
                ),
                Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.colorScheme.outlineVariant),
              ],
            ),
            // Scrollable visit history with a pinned "Visit History" header.
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  if (state.patient.isArchived)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: _RestoreBanner(onRestore: _restore),
                      ),
                    ),
                  // Pinned header: title + total-owed toggle chip.
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _VisitHistoryHeaderDelegate(
                      height: 60,
                      background: theme.scaffoldBackgroundColor,
                      child: _VisitHistoryHeader(
                        totalOwed: state.totalOwed,
                        showOwedOnly: _showOwedOnly,
                        onToggle: _toggleOwedFilter,
                      ),
                    ),
                  ),
                  ..._buildVisitSlivers(context, state, l10n),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildVisitSlivers(
    BuildContext context,
    PatientDetailsState state,
    AppLocalizations l10n,
  ) {
    if (_showOwedOnly) {
      final owed = state.owedVisits;
      if (owed == null) {
        // Still fetching the full owed set.
        return const [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ];
      }
      if (owed.isEmpty) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.verified_outlined,
              title: l10n.noOwedVisitsTitle,
              message: l10n.noOwedVisitsBody,
            ),
          ),
        ];
      }
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          sliver: SliverList.builder(
            itemCount: owed.length,
            itemBuilder: (context, index) =>
                _visitCard(context, state, owed[index]),
          ),
        ),
      ];
    }

    // Default: recent visits, paginated.
    if (state.visits.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.event_note_outlined,
            title: l10n.emptyNoVisitsTitle,
            message: l10n.emptyNoVisitsBody,
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        sliver: SliverList.builder(
          itemCount: state.visits.length + (state.hasMoreVisits ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= state.visits.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _visitCard(context, state, state.visits[index]);
          },
        ),
      ),
    ];
  }

  Widget _visitCard(
    BuildContext context,
    PatientDetailsState state,
    Visit visit,
  ) {
    return VisitCard(
      visit: visit,
      canEdit: !state.patient.isArchived,
      onEdit: () => context.push(
        '/patient/${widget.patientId}/visit/edit',
        extra: visit,
      ),
      onDelete: () => _deleteVisit(visit),
    );
  }
}

class _VisitHistoryHeader extends StatelessWidget {
  const _VisitHistoryHeader({
    required this.totalOwed,
    required this.showOwedOnly,
    required this.onToggle,
  });

  final int totalOwed;
  final bool showOwedOnly;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    // Only offer the toggle when there is a balance to look at (or it is
    // already active).
    final showChip = totalOwed > 0 || showOwedOnly;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Text(
            l10n.visitHistory,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (showChip)
            FilterChip(
              selected: showOwedOnly,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              tooltip: l10n.owedOnlyTooltip,
              avatar: Icon(
                showOwedOnly
                    ? Icons.account_balance_wallet_rounded
                    : Icons.account_balance_wallet_outlined,
                size: 18,
                color: showOwedOnly
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.error,
              ),
              label: Text(
                l10n.owedTotal(JodMoney.format(totalOwed, locale: locale)),
              ),
              onSelected: onToggle,
            ),
        ],
      ),
    );
  }
}

class _VisitHistoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  _VisitHistoryHeaderDelegate({
    required this.height,
    required this.child,
    required this.background,
  });

  final double height;
  final Widget child;
  final Color background;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    return Material(
      color: background,
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Expanded(child: child),
            // A separator appears only once the header actually overlaps
            // scrolled cards, so it reads as "pinned".
            if (overlapsContent)
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant,
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _VisitHistoryHeaderDelegate oldDelegate) => true;
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({required this.patient, required this.onCall});

  final Patient patient;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PatientAvatar(
          initials: patient.initials,
          seedText: patient.name,
          radius: 34,
          muted: patient.isArchived,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                patient.name,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      patient.phoneNumber,
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (patient.isArchived) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(l10n.archivedChip,
                          style: theme.textTheme.labelSmall),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: l10n.callPatient,
          onPressed: onCall,
          icon: const Icon(Icons.call_rounded),
        ),
      ],
    );
  }
}

class _RestoreBanner extends StatelessWidget {
  const _RestoreBanner({required this.onRestore});
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined,
              color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(l10n.restorePatientBody)),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onRestore,
            child: Text(l10n.restorePatientConfirm),
          ),
        ],
      ),
    );
  }
}
