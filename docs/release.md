# Release configuration and checks

## Android identity and signing

Use the registered application ID for this product. The debug namespace remains unchanged so existing development installs remain usable. Set `PH_APPLICATION_ID` when building production:

```sh
export PH_APPLICATION_ID=your.registered.applicationid
flutter build appbundle --release
```

Create `android/key.properties` locally with `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`. Paths are relative to the Android project directory unless absolute. This file and keystores are ignored by Git. Supply them through protected CI secrets for a real release. No signing material is included in the repository.

Normal release builds fail if the application ID is missing/an example or signing configuration is incomplete. `PH_UNSIGNED_VALIDATION=true flutter build apk --release` is an explicit compile-only path used by CI. Its artifact is unsigned and must not be distributed as a production release. Do not set that flag for store uploads.

## iOS identity

The project keeps the existing development team and development bundle identifiers. Select the owner's registered production bundle ID and signing profile in Xcode before archiving. CI runs `flutter build ios --release --no-codesign` only; this checks compilation, not distribution readiness.

## Required verification

- CI passes formatting, analysis, regression tests, offline asset checks, and unsigned Android/iOS compilation.
- On real Android and iOS devices: grant/deny/revoke camera permission; background/resume; rotate; navigate away during initialization; choose gallery photos; cancel selection; capture/confirm/save/reopen/share; try offline mode; test interrupted Android image picking.
- Select known colored image patches in portrait, landscape, and EXIF-rotated photos. Verify selected pixels, thumbnails, stored overlays, and PDF annotations agree.
- Verify camera failure never shows or records a demo without explicit selection. Verify every demo, unvalidated result, and legacy record stays identified after saving and sharing.
- Test missing/corrupted history, storage exhaustion, interrupted saves, older records, orphan cleanup, and user-controlled deletion. Do not erase history to hide an initialization failure.
- Test large text, screen readers, move/resize controls, small phones, reduced motion, long/Unicode notes, and iPad sharing.
- Inspect a release bundle for `.env` assets or credentials, and inspect the merged Android manifest to ensure no dependency adds Internet or microphone permission.
- Approve the measurement validation described in `measurement_validation.md`, or retain experimental labeling and limit the release claims accordingly.
- Use a small beta first and monitor actionable user-reported diagnostics. Keep a known-good build and retain schema compatibility for rollback.

No cloud telemetry is enabled. Diagnostics are local and exclude image bytes, notes, paths, and exception messages. Previously distributed Gemini keys, if any, must be rotated/revoked by the account owner; removing them from this build does not revoke old copies.
