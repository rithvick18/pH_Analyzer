class CubicSpline {
  final List<double> x;
  final List<double> y;
  late final List<double> h;
  late final List<double> m;

  CubicSpline(List<double> xInput, List<double> yInput)
      : x = List<double>.from(xInput),
        y = List<double>.from(yInput) {
    if (x.length < 2 || x.length != y.length) {
      throw ArgumentError('CubicSpline requires at least 2 points and equal length x and y lists.');
    }

    final int n = x.length - 1;
    h = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      h[i] = x[i + 1] - x[i];
      if (h[i] <= 0) {
        throw ArgumentError('x array must be strictly increasing.');
      }
    }

    final int nPoints = x.length;
    final List<double> a = List<double>.filled(nPoints, 0.0);
    final List<double> b = List<double>.filled(nPoints, 0.0);
    final List<double> c = List<double>.filled(nPoints, 0.0);
    final List<double> d = List<double>.filled(nPoints, 0.0);

    // Natural spline boundary conditions: m_0 = 0, m_n = 0
    b[0] = 1.0;
    c[0] = 0.0;
    d[0] = 0.0;

    for (int i = 1; i < n; i++) {
      a[i] = h[i - 1];
      b[i] = 2.0 * (h[i - 1] + h[i]);
      c[i] = h[i];
      d[i] = 6.0 * ((y[i + 1] - y[i]) / h[i] - (y[i] - y[i - 1]) / h[i - 1]);
    }

    a[n] = 0.0;
    b[n] = 1.0;
    d[n] = 0.0;

    // Thomas algorithm
    final List<double> cPrime = List<double>.filled(nPoints, 0.0);
    final List<double> dPrime = List<double>.filled(nPoints, 0.0);

    cPrime[0] = c[0] / b[0];
    dPrime[0] = d[0] / b[0];

    for (int k = 1; k < nPoints; k++) {
      final double denom = b[k] - a[k] * cPrime[k - 1];
      if (denom == 0) {
        throw StateError('Thomas algorithm failed due to zero denominator.');
      }
      if (k < nPoints - 1) {
        cPrime[k] = c[k] / denom;
      }
      dPrime[k] = (d[k] - a[k] * dPrime[k - 1]) / denom;
    }

    m = List<double>.filled(nPoints, 0.0);
    m[nPoints - 1] = dPrime[nPoints - 1];
    for (int k = nPoints - 2; k >= 0; k--) {
      m[k] = dPrime[k] - cPrime[k] * m[k + 1];
    }
  }

  double interpolate(double xVal) {
    if (xVal <= x.first) {
      return y.first;
    }
    if (xVal >= x.last) {
      return y.last;
    }

    // Find interval i where xVal is in [x[i], x[i+1]]
    int i = 0;
    int low = 0;
    int high = x.length - 2;
    while (low <= high) {
      final int mid = low + ((high - low) >> 1);
      if (xVal >= x[mid] && xVal <= x[mid + 1]) {
        i = mid;
        break;
      } else if (xVal < x[mid]) {
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }

    final double hi = h[i];
    final double a = (x[i + 1] - xVal) / hi;
    final double bVal = (xVal - x[i]) / hi;

    final double yVal = a * y[i] +
        bVal * y[i + 1] +
        ((a * a * a - a) * m[i] + (bVal * bVal * bVal - bVal) * m[i + 1]) *
            (hi * hi) /
            6.0;

    return yVal;
  }
}
