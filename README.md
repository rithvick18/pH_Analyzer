# pH Analyzer

An **offline, experimental Flutter app** for estimating pH from test-strip photographs. It is not an independently validated measurement instrument. Results, saved history, and PDF reports identify readings as unvalidated estimates; demo readings are labeled separately.

Supported release targets are Android and iOS. Other platform folders are development scaffolding, not a claim of production support.

## Capture and analysis

1. Capture a still image or choose a gallery photo. Camera permission failures show an error and never substitute a demo photo.
2. On the normalized still photo, select the dye and reference-paper regions. Drawing and accessible move/resize buttons select the same image pixels. Reference paper can be disabled, with an explicit fixed-background warning.
3. The app runs acquisition checks and CIELAB/spline matching on-device. Colors too far from the calibration return “cannot determine.” Ambiguous and boundary matches are flagged.
4. Save the estimate with notes or explicitly share a PDF. Each new record retains the calibration hash, algorithm version, selected colors, quality warnings, source, and measurement time.

No API key, account, `.env` asset, cloud strip recognition, or network call is needed. Android's main/release manifest requests no Internet or microphone permission. Photos may leave the app only when the user invokes the operating system's share sheet; OS backups follow device settings.

Demo mode must be explicitly selected. It uses `assets/Reference.jpeg` and produces labeled demo results.

## Calibration and honest precision

`assets/calibration.json` contains eight experimental anchors. A candidate search covers **only the calibration's supported domain** at 0.1 pH intervals, also including exact anchors/endpoints. The display uses one decimal place. This is numerical resolution, not an accuracy claim.

Calibration schema 1 accepts a nonempty `id`, positive integer `version`, positive finite `max_color_distance`, and at least two unique anchors. Each anchor has finite pH in 0–14 and exactly three integer 0–255 channels for both `dye_rgb` and `bg_rgb`.

The current maximum color distance (15), ambiguity warning (another candidate at least 1 pH away within 1 Lab distance), dye-luminance bounds (40–230), and clipping threshold (20%) are **provisional engineering guards**. They require validation against independently measured samples. No percentage confidence or exact-pH claim is made. The robust mean discards the darkest 5% and brightest 5% of dye pixels.

See [measurement validation](docs/measurement_validation.md) for the evidence required before making accuracy claims. Updating calibration changes its saved hash; existing results retain their original provenance.

## Development

The checked toolchain is Flutter **3.41.6**, Dart **3.11.4**. CI uses the same Flutter version.

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
python3 tool/check_offline_assets.py
flutter run
```

The regression suite covers calibration boundaries, invalid calibration, out-of-calibration rejection, image transforms, orientation, offline quality checks, provenance round trips, legacy records, storage errors, demo behavior, and PDF generation. Synthetic tests do not replace physical-device or laboratory validation.

Large inputs are bounded to 25 MB / 24 megapixels and one frame. The selection view creates a lossless PNG snapshot capped at 6 megapixels; every ROI refers to that snapshot. Analysis decodes once for prediction and thumbnails. Saved images use UUID names under app documents; owned temporary and orphan files are cleaned conservatively.

Existing Hive records remain readable and are labeled as legacy estimates with unknown validation. Unreadable storage is reported as an error rather than empty history. No automatic destructive reset is performed.

## Release

See [release setup and acceptance checks](docs/release.md). Android release builds no longer use debug signing. A production application ID and the owner's release credentials must be supplied; they are not invented or committed here. CI creates unsigned compile-validation artifacts only. iOS retains the existing development bundle configuration until the owner chooses the production identity.

Local diagnostics store only a bounded list of error types, stages, and timestamps. Users can copy them from Settings; the app does not upload telemetry.
