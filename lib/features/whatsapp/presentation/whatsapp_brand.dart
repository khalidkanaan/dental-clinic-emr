import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:material_ui/material_ui.dart';

/// WhatsApp colors, tuned to read well in both light and dark themes.
class WhatsAppColors {
  const WhatsAppColors._();

  static const Color green = Color(0xFF25D366);
  static const Color teal = Color(0xFF128C7E);

  /// Icon color on the tinted button.
  static Color foreground(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark ? green : teal;

  /// Soft tinted background for the button.
  static Color container(ColorScheme scheme) => green.withValues(
        alpha: scheme.brightness == Brightness.dark ? 0.20 : 0.16,
      );

  /// Outgoing chat bubble, as in WhatsApp itself.
  static Color bubble(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark
          ? const Color(0xFF005C4B)
          : const Color(0xFFD9FDD3);

  static Color onBubble(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark
          ? const Color(0xFFE9EDEF)
          : const Color(0xFF111B21);
}

/// Round WhatsApp button that matches the tonal call button beside it.
class WhatsAppButton extends StatelessWidget {
  const WhatsAppButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
  });

  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: WhatsAppColors.container(scheme),
        foregroundColor: WhatsAppColors.foreground(scheme),
      ),
      icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 22),
    );
  }
}
