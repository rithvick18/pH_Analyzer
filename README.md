# pH Analyzer

An **experimental Flutter app** for estimating pH from test-strip photographs. Gemini mode checks photos for dye-pad identity; manual mode runs color analysis locally without an AI check. It is not an independently validated measurement instrument. Demo readings are labeled separately.

Supported release targets are Android and iOS. Other platform folders are development scaffolding, not a claim of production support.

## Capture and analysis

1. Open **Use Live Camera**, point it at one dye patch, and tap **Capture** when the image is clear. The camera takes a photo only when you tap the button. A white background is not required.
2. The captured photo opens the region selector so you can mark the dye pad yourself. You can also choose a gallery photo and select its dye region.
3. Reference paper is optional and off by default in the manual selector. Without a selected reference region, the app uses its bundled reference color and warns that lighting was not corrected. Use even light and avoid glare or deep shadows.
4. In Gemini mode, the app checks whether the selected sample photo shows a dye pad. Invalid or uncertain photos do not produce a pH result. In manual mode, this check is skipped and results are marked accordingly. The app runs acquisition checks and CIELAB/spline matching on-device in both modes. Colors too far from the calibration return “cannot determine.” Ambiguous and boundary matches are flagged.
5. The result is displayed first; tap **Save to History** to keep it, optionally with a note, or share a PDF explicitly. Each saved record retains the calibration hash, algorithm version, selected colors, quality warnings, source, and measurement time.

The pH estimate depends on the bundled calibration, which has not been independently validated for a particular strip brand, phone, or lighting setup.

On first launch, choose Gemini validation or manual mode, then select the bundled calibration or create a named one. Gemini mode stores your API key using device secure storage and sends sample photos and selected dye regions to Gemini for identity checks. Manual mode needs no API key or network connection and calculates pH locally from CIELAB colors without confirming dye-pad identity. The result and history identify manual estimates as unvalidated. Settings lets you add or replace the key, or switch to manual mode by deleting it. For a distributed app, move API access to a backend. History and pH estimation remain local in either mode.

Demo mode must be explicitly selected. It uses `assets/Reference.jpeg`, skips Gemini, and produces labeled demo results rather than sample measurements. Live-camera zoom is limited to 1.0×–5.0× when the device camera supports that range.

## Calibration and honest precision

### Dye-specific profiles

Open **Settings → Calibration Manager → New profile**. Name the dye or strip profile and optionally record its brand, product, lot, and notes. Set the supported pH range, then add at least two distinct known pH points in ascending order. The first and last point must match the range endpoints. For each point, enter dye and reference-paper RGB values manually, or capture/import a photo and select those regions. Gemini validates calibration photos when a key is configured; manual mode extracts colors without AI validation. Reference selection is optional; when omitted, the app uses the fixed RGB value (245, 245, 240) and does not correct for lighting.

Use certified buffer solutions or a reliable pH meter to establish known pH values. Keep dye, strip lot, lighting, phone camera, and region selection consistent. Calibration quality depends on all of these, and user-created profiles remain **experimental, unvalidated estimates**. A custom profile does not establish accuracy.

Select a profile in Calibration Manager or in the photo region selector before analysis. The region selector shows the active dye profile for that analysis. The bundled experimental profile remains the default and cannot be edited or deleted. Editing a profile increases its version; duplicating gives it a new ID. Deleting an active profile selects the bundled default after confirmation. Analysis uses a snapshot of the chosen anchors and searches only within that profile's calibrated pH range. Colors too far from those anchors are rejected; a boundary estimate is flagged because the sample may lie beyond the range.

Profiles are stored separately from measurement history. A profile stores its stable ID, version, name, optional metadata, range, dye RGB and reference RGB for every point, and calibration settings. Each new measurement stores the selected profile ID and version, a deterministic SHA-256 calibration hash, the algorithm version, observed colors, source, time, warnings, and the existing image/history details. Editing or deleting a profile does not rewrite prior measurements. Older history entries remain readable, including entries without the newer profile ID and version fields. Damaged or incompatible profile storage is reported as an error and does not clear history.

`assets/calibration.json` contains eight experimental anchors. A candidate search covers **only the calibration's supported domain** at 0.1 pH intervals, also including exact anchors/endpoints. The display uses one decimal place. This is numerical resolution, not an accuracy claim.

Calibration schema 1 accepts a nonempty `id`, positive integer `version`, positive finite `max_color_distance`, and at least two distinct anchors in ascending pH order. Each anchor has finite pH in 0–14 and exactly three integer 0–255 channels for both `dye_rgb` and `bg_rgb`.

The current maximum color distance (15), ambiguity warning (another candidate at least 1 pH away within 1 Lab distance), dye-luminance bounds (40–230), clipping threshold (20%), and automatic patch shape/color checks are **provisional engineering guards**. They require validation against independently measured samples. No percentage confidence or exact-pH claim is made. The robust mean discards the darkest 5% and brightest 5% of dye pixels.

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

The regression suite covers calibration boundaries, invalid calibration, out-of-calibration rejection, automatic patch detection on a colored background, non-dye examples, image transforms, orientation, offline quality checks, provenance round trips, legacy records, storage errors, demo behavior, and PDF generation. Synthetic tests do not replace physical-device or laboratory validation.

Large inputs are bounded to 25 MB / 24 megapixels and one frame. Camera scanning and the selection view create a lossless PNG snapshot capped at 6 megapixels; every selected region refers to that snapshot. Analysis decodes once for prediction and thumbnails. Saved images use UUID names under app documents; owned temporary and orphan files are cleaned conservatively.

Existing Hive records remain readable and are labeled as legacy estimates with unknown validation. Unreadable storage is reported as an error rather than empty history. No automatic destructive reset is performed.

## Release

See [release setup and acceptance checks](docs/release.md). Android release builds no longer use debug signing. A production application ID and the owner's release credentials must be supplied; they are not invented or committed here. CI creates unsigned compile-validation artifacts only. iOS retains the existing development bundle configuration until the owner chooses the production identity.

Generated build output, APKs, local signing material, and analysis caches are excluded from Git. Share an installable, signed APK separately through a GitHub Release or a file-sharing service; do not commit the APK or signing key to this repository. The local test APK is stored in the ignored `local-release/` folder on the build machine and is not included when someone clones the repository.

Local diagnostics store only a bounded list of error types, stages, and timestamps. Users can copy them from Settings; the app does not upload telemetry.
