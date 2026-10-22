# SBPS Mobile

Aplikasi Presensi & Proyek (SBPS) — Flutter unified app (staging/production via `--dart-define-from-file=env/*.json`).

## Ringkasan

| Item | Nilai |
|---|---|
| ApplicationId Android | `com.sbps.mobile` |
| Flutter | 3.38.5 (dipin, harus sama lokal & CI) |
| Dart SDK | ^3.10.4 |
| Rilis awal | `1.0.0+1` |

## Prasyarat

- Flutter 3.38.5
- Shorebird CLI (`shorebird doctor` hijau) — untuk rilis/patch OTA
- `android/key.properties` + `upload-keystore.jks` lokal untuk build release bertanda tangan (gitignored)

## Perintah dasar

```bash
flutter analyze
flutter test

# Staging / Production (unified app)
flutter run --dart-define-from-file=env/staging.json
flutter run --dart-define-from-file=env/production.json
```

## Rilis & OTA (Shorebird)

- **Release baru** (perubahan native/versi baru): naikkan `version:` di `pubspec.yaml`, lalu `shorebird release android --build-number <N> --dart-define-from-file=env/production.json`.
- **Patch OTA** (perubahan Dart-only): `shorebird patch android --dart-define-from-file=env/production.json` — patch aktif pada pembukaan app berikutnya.
- Detail: `docs/SHOREBIRD-RUNBOOK.md`.

## CI/CD (Codemagic)

- `codemagic.yaml`: workflow `sbps-android` (push `develop`/`main`/tag `v*`) → gate analyze+test → `shorebird release` → Firebase App Distribution; workflow manual `sbps-patch` → `shorebird patch`.
- Env var groups: `android-signing`, `firebase-app-distribution`, `shorebird` (SHOREBIRD_TOKEN), `notifications`.
