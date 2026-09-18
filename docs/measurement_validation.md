# Measurement validation before accuracy claims

The bundled calibration and quality thresholds are experimental. Passing software tests establishes implementation behavior, not measurement accuracy.

Define the intended strip brand and lot, valid pH interval, sample types, reaction timing, required reference paper, illumination, and supported phones. Follow the strip manufacturer's instructions for sample handling and reading time. Do not infer reference pH from a household substance label.

Collect paired strip photographs and independent reference measurements. Preserve raw images, normalized snapshots, selected ROIs, calibration/algorithm versions, device/camera identity, strip lot, lighting, reading time, and reference measurement provenance. Include repeats, blank/non-strip negatives, glare, shadows, motion blur, and samples outside the intended pH range.

Keep calibration/training images separate from validation images. Separate phone/lot/session groups to avoid evaluating near-duplicate captures from the same sample on both sides. Test the complete acquisition-to-report workflow.

Before evaluating, specify acceptable error, bias, repeatability, and rejection rates for the intended use. Report sample counts, mean absolute error, signed bias, high-percentile absolute error, repeatability, accepted/rejected counts, and subgroup results. A single overall average can hide device- or range-specific failures.

Tune color-distance and image-quality rejection thresholds only on development data, then evaluate untouched holdout data. Calibrate any uncertainty interval empirically. Never turn a raw color-distance score into a percentage confidence without evidence.

Release gate: the owner approves a written validation report and operating envelope. Until then, retain the unvalidated estimate labeling and avoid accuracy or suitability claims. No reference dataset or independently measured results were supplied with this repository.
