import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:material_ui/material_ui.dart';

import 'package:dental_clinic/core/widgets/app_dialogs.dart';
import 'package:dental_clinic/features/whatsapp/application/whatsapp_message.dart';
import 'package:dental_clinic/features/whatsapp/application/whatsapp_settings_controller.dart';
import 'package:dental_clinic/features/whatsapp/domain/message_template.dart';
import 'package:dental_clinic/features/whatsapp/presentation/placeholder_help_sheet.dart';
import 'package:dental_clinic/features/whatsapp/presentation/whatsapp_brand.dart';
import 'package:dental_clinic/l10n/app_localizations.dart';

/// Settings card for the message prepared by the patient WhatsApp button.
class WhatsAppSettingsCard extends ConsumerStatefulWidget {
  const WhatsAppSettingsCard({super.key});

  @override
  ConsumerState<WhatsAppSettingsCard> createState() =>
      _WhatsAppSettingsCardState();
}

class _WhatsAppSettingsCardState extends ConsumerState<WhatsAppSettingsCard> {
  final _template = TextEditingController();
  final _clinicName = TextEditingController();
  final _countryCode = TextEditingController();
  final _templateFocus = FocusNode();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_template, _clinicName, _countryCode]) {
      c.addListener(_onChanged);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // First build, or the app language changed: show the saved values (the
    // default message follows the language) unless there are unsaved edits.
    if (!_isDirty) _resetFields();
  }

  @override
  void dispose() {
    _template.dispose();
    _clinicName.dispose();
    _countryCode.dispose();
    _templateFocus.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  AppLocalizations get _l10n => AppLocalizations.of(context);
  String get _language => Localizations.localeOf(context).languageCode;
  String get _defaultTemplate =>
      WhatsAppMessage.defaultTemplate(_l10n, _language);

  WhatsAppSettings get _saved => ref.read(whatsAppSettingsControllerProvider);

  /// Remembers what the fields were last filled with, so edits can be told
  /// apart from values that were loaded.
  String _loadedTemplate = '';
  String _loadedClinic = '';
  String _loadedCode = '';

  bool get _isDirty =>
      _template.text != _loadedTemplate ||
      _clinicName.text != _loadedClinic ||
      _countryCode.text != _loadedCode;

  void _resetFields([WhatsAppSettings? settings]) {
    final s = settings ?? _saved;
    _loadedTemplate = s.templateOr(_defaultTemplate);
    _loadedClinic = s.clinicName ?? '';
    _loadedCode = s.countryCode;
    _template.text = _loadedTemplate;
    _clinicName.text = _loadedClinic;
    _countryCode.text = _loadedCode;
  }

  void _insertToken(String token) {
    final text = _template.text;
    final selection = _template.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final newText = text.replaceRange(start, end, token);
    _template.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    _templateFocus.requestFocus();
  }

  Map<MessagePlaceholder, String> get _sampleValues =>
      WhatsAppMessage.sampleValues(
        l10n: _l10n,
        clinicName: _clinicName.text.trim().isEmpty
            ? _l10n.appTitle
            : _clinicName.text.trim(),
        locale: _language,
      );

  Future<void> _save() async {
    final l10n = _l10n;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    // Store nothing when the message is the default, so it keeps following
    // the app language.
    final text = _template.text;
    final isDefault = text.trim() == _defaultTemplate.trim();

    try {
      await ref.read(whatsAppSettingsControllerProvider.notifier).save(
            template: isDefault ? null : text,
            countryCode: _countryCode.text,
            clinicName: _clinicName.text,
          );
      if (!mounted) return;
      _resetFields();
      showAppSnackBar(context, l10n.whatsappSaved);
    } catch (_) {
      if (mounted) showAppSnackBar(context, l10n.errUnknown);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Stored settings arrive shortly after start-up; fill them in unless the
    // user has already started typing.
    ref.listen<WhatsAppSettings>(whatsAppSettingsControllerProvider,
        (_, next) {
      if (!_isDirty) _resetFields(next);
    });

    final unknown = MessageTemplate.unknownTokens(_template.text);
    final preview = MessageTemplate.render(_template.text, _sampleValues);
    final canReset = _template.text.trim() != _defaultTemplate.trim();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FaIcon(FontAwesomeIcons.whatsapp,
                    size: 18, color: WhatsAppColors.foreground(scheme)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.whatsappSettingsTitle,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: l10n.placeholdersTitle,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showPlaceholderHelp(
                    context,
                    sampleValues: _sampleValues,
                    onInsert: _insertToken,
                  ),
                  icon: const Icon(Icons.help_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.whatsappSettingsBody,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _template,
              focusNode: _templateFocus,
              enabled: !_saving,
              minLines: 4,
              maxLines: 10,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.whatsappMessageLabel,
                hintText: l10n.whatsappMessageHint,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: _saving
                      ? null
                      : () => showPlaceholderHelp(
                            context,
                            sampleValues: _sampleValues,
                            onInsert: _insertToken,
                          ),
                  icon: const Icon(Icons.data_object_rounded, size: 18),
                  label: Text(l10n.placeholdersTitle),
                ),
                if (canReset)
                  TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () {
                            _template.text = _defaultTemplate;
                          },
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: Text(l10n.whatsappResetDefault),
                  ),
              ],
            ),
            if (unknown.isNotEmpty) ...[
              const SizedBox(height: 10),
              _WarningBanner(
                message: l10n.whatsappUnknownPlaceholders(unknown.join('  ')),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              l10n.whatsappPreview,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            _PreviewBubble(text: preview),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _clinicName,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.whatsappClinicName,
                      hintText: l10n.appTitle,
                      helperText: l10n.whatsappClinicNameHelper(
                          MessagePlaceholder.clinic.tokenFor(_language)),
                      helperMaxLines: 2,
                      prefixIcon: const Icon(Icons.local_hospital_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _countryCode,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.whatsappCountryCode,
                      prefixText: '+',
                      helperText: l10n.whatsappCountryCodeHelper,
                      helperMaxLines: 2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                onPressed: (_saving || !_isDirty) ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(l10n.actionSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The rendered message shown as an outgoing WhatsApp bubble.
class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: WhatsAppColors.bubble(scheme),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(rtl ? 4 : 14),
              bottomRight: Radius.circular(rtl ? 14 : 4),
            ),
          ),
          child: Text(
            text.isEmpty ? ' ' : text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: WhatsAppColors.onBubble(scheme),
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
