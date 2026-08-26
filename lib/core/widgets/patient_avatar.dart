import 'package:material_ui/material_ui.dart';

/// A circular avatar showing a patient's initials, tinted deterministically
/// from the name so patients are visually distinguishable.
class PatientAvatar extends StatelessWidget {
  const PatientAvatar({
    super.key,
    required this.initials,
    required this.seedText,
    this.radius = 24,
    this.muted = false,
  });

  final String initials;
  final String seedText;
  final double radius;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hue = (seedText.hashCode % 360).abs().toDouble();
    final baseColor = muted
        ? scheme.surfaceContainerHighest
        : HSLColor.fromAHSL(1, hue, 0.45, 0.55).toColor();

    return CircleAvatar(
      radius: radius,
      backgroundColor: muted
          ? scheme.surfaceContainerHighest
          : baseColor.withValues(alpha: 0.18),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w600,
          color: muted ? scheme.onSurfaceVariant : baseColor,
        ),
      ),
    );
  }
}
