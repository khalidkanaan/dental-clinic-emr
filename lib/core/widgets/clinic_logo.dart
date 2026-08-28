import 'package:material_ui/material_ui.dart';

class ClinicLogo extends StatelessWidget {
  const ClinicLogo({
    super.key,
    this.width = 165,
    this.height = 40,
    this.semanticLabel,
  });

  static const String assetPath =
      'assets/images/clinic_logo.png';

  final double width;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: BoxFit.contain,
        alignment: AlignmentDirectional.centerStart,
        color: colors.onSurfaceVariant,
        colorBlendMode: BlendMode.srcIn,
        semanticLabel: semanticLabel,
      ),
    );
  }
}