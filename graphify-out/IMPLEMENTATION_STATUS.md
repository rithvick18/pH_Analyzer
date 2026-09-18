# Implementation status — 18 September 2026

User decision: all analysis remains on-device; results are explicitly unvalidated estimates.

## Applied

- Removed Gemini calls, client credential loading, SDK and dotenv dependencies, and bundled `.env`. Release Android manifest excludes Internet and microphone permissions, including the camera dependency's microphone declaration.
- Replaced invented confidence/precision claims with persistent estimate, demo and quality labels in results, history and PDFs.
- Unified camera and gallery analysis around a normalized, lossless photo and image-coordinate region selections. Removed forced landscape rotation; retained EXIF normalization and compatibility for older saved records.
- Strict immutable calibration; atomic model replacement; search restricted to calibration endpoints; color-distance rejection and ambiguity/boundary warnings. Thresholds remain experimental.
- Explicit camera errors, retry/gallery fallback and deliberate demo selection; serialized lifecycle disposal/reinitialization; optional camera controls fail gracefully.
- Shared decode/quality/color/provenance pipeline with file/pixel limits, bounded-memory trimmed color extraction and small thumbnails.
- Immutable measurement snapshots record original time, calibration hash, algorithm, RGB/Lab, source, dimensions and warnings. Legacy records remain readable and labeled.
- Storage errors propagate; owned images use UUID-relative paths; failed saves roll back unreferenced images; cleanup waits until history can be read. Home refreshes after history changes.
- PDF reports preserve the stored estimate/provenance, distinguish measurement/report times, support optional reference regions and use the same region geometry. Notes use device font rasterization; tablet share origin is provided.
- Accessible region move/resize controls, scrollable small-screen selection, reduced-motion handling, and local bounded diagnostics without photos, notes, paths or exception messages.
- Pinned Flutter CI checks formatting, analysis, tests, offline assets and both platform compilations. Production Android builds require owner identity/signing; compile-only unsigned artifacts use an explicit flag.

## Verified locally

Flutter 3.41.6 / Dart 3.11.4:

- Formatting check and `flutter analyze --no-pub`: clean.
- `flutter test --no-pub --coverage`: 29 tests pass.
- Regressions include calibration boundaries and malformed input, out-of-calibration rejection, EXIF/landscape geometry, camera/gallery/demo equivalence, storage round trip and legacy adapter, corrupted history, single-region PDF export, explicit demo behavior, and photo → analyze → save → history flow.
- The photo selection workflow also passes at 320 × 568 logical pixels with 200% text scaling.
- Unsigned Android release APK and iOS release Runner.app compile successfully. These are verification artifacts, not distribution-signed releases.
- Android release asset/merged-manifest checks pass: no `.env`, Internet or microphone permission.
- Normal Android release validation fails as intended without a registered production application ID.
- Generated one-page PDF visually inspected: readable, complete, no overlapping/clipped sections. Unicode notes and real share extensions still need device QA.

## Remaining release gates

Use `docs/release.md` for production IDs/signing, physical-device permission/lifecycle/orientation/share testing, accessibility checks, storage-exhaustion/interruption testing and staged rollout. Automated tests do not exercise a physical camera, OS permission dialogs or share extensions.

Use `docs/measurement_validation.md` for the independent dataset and operating-envelope validation. No supported strip/lot, clinical accuracy, confidence probability, blur/uniformity threshold, or reaction timing is invented. Ambiguous matches are warned, not automatically rejected; local quality checks cannot establish strip identity. Until independently validated, retain experimental labeling and avoid accuracy/suitability claims.

Any previously distributed cloud credential requires owner revocation; removing the asset does not revoke old copies. No deployment or store submission was performed.

## Graph update

Code and five changed documentation/configuration files refreshed: 924 nodes, 1,121 edges, 98 communities. Post-merge endpoint diagnostics found no dangling endpoints. The earlier raw-extraction edge-collapse limitations are not disproved by a post-merge check; the graph remains navigation context, not a runtime call trace. The Linux `my_application.h` parser warning remains (mobile is the supported target). Host-agent semantic token counts are unavailable; zero counters are placeholders. The original audit remains historical, not an assessment of current code.
