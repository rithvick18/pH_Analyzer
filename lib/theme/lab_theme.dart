import 'dart:ui';
import 'package:flutter/material.dart';

class LabTheme {
  // Deep Scientific Dark Palette
  static const Color bgDark = Color(0xFF0D1117);
  static const Color surfaceCard = Color(0xFF161B22);
  static const Color surfaceElevated = Color(0xFF21262D);
  static const Color borderDark = Color(0xFF30363D);

  // Vibrant Accents
  static const Color cyanAccent = Color(0xFF00D2FF);
  static const Color tealAccent = Color(0xFF00E5FF);
  static const Color darkTeal = Color(0xFF0E3A42);

  // pH Indicator Glow Palette
  static const Color phAcidicRed = Color(0xFFFF453A);
  static const Color phAcidicOrange = Color(0xFFFF9F0A);
  static const Color phNeutralGreen = Color(0xFF30D158);
  static const Color phBasicBlue = Color(0xFF64D2FF);
  static const Color phAlkalinePurple = Color(0xFFBF5AF2);

  static Color getPhColor(double ph) {
    if (ph < 3.0) return phAcidicRed;
    if (ph < 5.0) return phAcidicOrange;
    if (ph < 6.5) return const Color(0xFFFFD60A); // Yellow
    if (ph <= 7.5) return phNeutralGreen;
    if (ph < 10.0) return phBasicBlue;
    if (ph < 12.0) return const Color(0xFF5E5CE6); // Indigo
    return phAlkalinePurple;
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final Color? color;
  final Color? borderColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? boxShadow;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 12.0,
    this.color,
    this.borderColor,
    this.borderRadius = 16.0,
    this.padding,
    this.margin,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? LabTheme.surfaceCard.withValues(alpha: 0.7);
    final effectiveBorderColor =
        borderColor ?? LabTheme.borderDark.withValues(alpha: 0.6);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: effectiveColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: effectiveBorderColor, width: 1.2),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
