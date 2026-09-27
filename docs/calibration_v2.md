# Bundled calibration v2

The eight anchors in `assets/calibration.json` are the user-supplied dye and
background RGB measurements, sorted by pH. Version 2 distinguishes this dataset
from the previous bundled calibration in saved measurement provenance.

## Approximation between references

The existing analyzer converts each dye/background pair to a CIELAB difference
and fits natural cubic splines through the measured points. It searches those
curves at 0.1 pH intervals, including the exact anchors and endpoints, to find the
closest color match. This provides estimates for missing pH values within 0–14;
no synthetic RGB values are inserted as measured calibration anchors.

Interpolated results now include a warning naming the surrounding measured pH
references. The search spacing is not an accuracy guarantee or an uncertainty
buffer. No numerical error margin can be established from these eight samples
alone. The existing color-distance rejection threshold is unchanged.

The largest gap is pH 2.9–7.0. Estimates in this interval depend heavily on the
assumed curve; measurements at pH 4, 5, and 6 would help check it. Cubic splines can
bend beyond the endpoint color values between anchors, and intermediate colors
have not been experimentally verified. There is no extrapolation outside 0–14.

## Patterns in the supplied measurements

- Red is the largest dye channel at every measured pH.
- The acidic samples are broadly red/pink; the higher-pH samples trend toward
  muted brown/yellow. This is a broad trend, not a monotonic color rule.
- Brightness is not monotonic: the dye becomes brighter through pH 2.9, darker
  toward pH 9.5, then brighter again toward pH 14. One RGB channel or brightness
  alone therefore cannot describe these references with a simple monotonic rule.
- Backgrounds are neutral gray, except for a small channel difference at pH 9.5.
  Their values vary from 185 to 211, so using each measured background matters.

For new captures, select a background region alongside the dye region. The
existing optional-background path still assumes RGB [245, 245, 240], which differs
from these measured backgrounds and may shift the estimate. This update does not
change that capture workflow or establish physical pH accuracy.

## Verification

Pipeline tests check that all eight measured dye/background pairs recover their
reference pH and that an intermediate color produces a labeled interpolated
estimate. These check software behavior, not accuracy on new physical samples.
