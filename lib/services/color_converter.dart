import 'dart:math' as math;

class ColorConverter {
  static const double _xn = 0.95047;
  static const double _yn = 1.00000;
  static const double _zn = 1.08883;
  static const double _delta = 6.0 / 29.0;
  static final double _deltaCubed = math.pow(_delta, 3).toDouble();
  static final double _factor = 3.0 * math.pow(_delta, 2).toDouble();

  /// Converts single sRGB channel [0, 1] to linear RGB space.
  static double _linearize(double c) {
    if (c <= 0.04045) {
      return c / 12.92;
    } else {
      return math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }
  }

  /// f(t) used in CIELAB transformation.
  static double _f(double t) {
    if (t > _deltaCubed) {
      return math.pow(t, 1.0 / 3.0).toDouble();
    } else {
      return (t / _factor) + (4.0 / 29.0);
    }
  }

  /// Converts an RGB color [0..255, 0..255, 0..255] to CIELAB [L*, a*, b*].
  static List<double> rgbToLab(List<int> rgb) {
    final double rNorm = (rgb[0] / 255.0).clamp(0.0, 1.0);
    final double gNorm = (rgb[1] / 255.0).clamp(0.0, 1.0);
    final double bNorm = (rgb[2] / 255.0).clamp(0.0, 1.0);

    final double rLin = _linearize(rNorm);
    final double gLin = _linearize(gNorm);
    final double bLin = _linearize(bNorm);

    final double x = 0.4124564 * rLin + 0.3575761 * gLin + 0.1804375 * bLin;
    final double y = 0.2126729 * rLin + 0.7151522 * gLin + 0.0721750 * bLin;
    final double z = 0.0193339 * rLin + 0.1191920 * gLin + 0.9503041 * bLin;

    final double fx = _f(x / _xn);
    final double fy = _f(y / _yn);
    final double fz = _f(z / _zn);

    final double l = 116.0 * fy - 16.0;
    final double a = 500.0 * (fx - fy);
    final double b = 200.0 * (fy - fz);

    return [l, a, b];
  }

  /// Computes [ΔL, Δa, Δb] = Lab_dye - Lab_bg
  static List<double> deltaLab(List<int> dyeRgb, List<int> bgRgb) {
    final labDye = rgbToLab(dyeRgb);
    final labBg = rgbToLab(bgRgb);

    return [
      labDye[0] - labBg[0],
      labDye[1] - labBg[1],
      labDye[2] - labBg[2],
    ];
  }
}
