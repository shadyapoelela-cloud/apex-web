# APEX Mobile Build Guide

This Flutter project already targets **web**, **Android**, **iOS**, **macOS**, **Linux**, and **Windows**. The web build is the primary deliverable — native builds are supported but need a one-time per-platform setup.

---

## Supported platforms

| Platform | Status | Tested |
|----------|--------|--------|
| Web (canvaskit) | ✅ Production | Yes |
| Android (API 21+) | 🟡 Ready to build | Needs signing keys |
| iOS 13+ | 🟡 Ready to build | Needs Apple developer account |
| macOS | 🟡 Ready to build | Debug tested |
| Linux / Windows | 🟡 Ready to build | Not regression-tested |

---

## Prerequisites

### All platforms
- Flutter SDK ≥ 3.22 (project tested with 3.24)
- Dart ≥ 3.4

### Android
- Android Studio or `sdkmanager`
- Android SDK 34+ (API 34)
- JDK 17+
- Gradle 8+
- Optional: a keystore file for release signing

### iOS
- macOS with Xcode 15+
- Active Apple Developer account ($99/yr) for TestFlight / App Store
- CocoaPods (`sudo gem install cocoapods`)
- A device or simulator running iOS 13+

---

## Bundle identifiers

- **Android:** `com.apexfinance.apex_finance`
- **iOS:** Set `PRODUCT_BUNDLE_IDENTIFIER` in Xcode — suggested `com.apexfinance.apex`

Change these **before publishing** to match the identifier you've registered with Google Play and Apple.

---

## App metadata

The app displays differently per locale:

| Locale | Display name |
|--------|--------------|
| `ar`   | آبكس |
| `en` (default) | APEX |

iOS: `CFBundleDevelopmentRegion=ar` and `CFBundleAllowMixedLocalizations=true` so RTL is the default when the device locale is Arabic.

Android: `android:supportsRtl="true"` on the application element; localized labels live in `android/app/src/main/res/values-ar/strings.xml`.

---

## Android build steps

```bash
# From apex_finance/
flutter pub get

# Debug APK (no signing, fast)
flutter build apk --debug

# Release APK (universal — larger file)
flutter build apk --release

# Split-per-ABI release APKs (recommended for Play Store)
flutter build apk --release --split-per-abi

# Play Store bundle (.aab)
flutter build appbundle --release
```

Outputs live under `build/app/outputs/`:
- `apk/release/app-release.apk` (universal)
- `apk/release/app-<abi>-release.apk` (split)
- `bundle/release/app-release.aab`

### Release signing
Create `android/key.properties` (git-ignored) pointing to your keystore:

```properties
storePassword=your-store-password
keyPassword=your-key-password
keyAlias=apex-key
storeFile=/absolute/path/to/apex-release-key.jks
```

Then add to `android/app/build.gradle.kts` (inside `android { ... }`):

```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
    }
}
buildTypes {
    release { signingConfig = signingConfigs.getByName("release") }
}
```

Generate the keystore once:
```bash
keytool -genkey -v -keystore apex-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias apex-key
```

**Never commit the keystore or `key.properties`.**

---

## iOS build steps

```bash
# From apex_finance/
flutter pub get
cd ios && pod install && cd ..

# Debug on a connected device or simulator
flutter run -d <device-id>

# Release archive
flutter build ios --release

# Open the Xcode workspace to sign + archive:
open ios/Runner.xcworkspace
# → Product → Archive → Distribute App
```

### Required Xcode setup
1. In Runner target → **Signing & Capabilities**, pick your Apple Developer team.
2. Set **Bundle Identifier** to something unique (e.g. `com.apexfinance.apex`).
3. If TestFlight: go through App Store Connect → "+ New App" → upload the archive.

---

## Configuring the backend URL

The web build points at `https://apex-api-ootk.onrender.com` by default. For mobile builds, either:

- Keep the default (app calls your cloud API over HTTPS), or
- Override at build time:

```bash
flutter build apk --release \
  --dart-define=API_BASE=https://api.your-domain.com
```

Source: [lib/core/api_config.dart](lib/core/api_config.dart).

---

## Assets & icons

Current icons live under:
- Android: `android/app/src/main/res/mipmap-*/ic_launcher.png`
- iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`

Replace these with the APEX gold-on-navy brand logo before store submission. Easiest path: [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons) — add a `flutter_launcher_icons` section to `pubspec.yaml`, drop in a 1024×1024 PNG, and run `dart run flutter_launcher_icons`.

---

## Testing responsive breakpoints in-app

Once running on a device, open `http://<host>:<port>/#/sprint44-operations` and tap the **Responsive Audit** tab. Previews render the dashboard at 375 / 768 / 1366 / 1920 widths simultaneously using `MediaQuery` overrides — a useful visual regression tool without leaving the app.

---

## CI/CD suggestions

- **Web:** GitHub Actions → `flutter build web` → deploy to GitHub Pages (already wired).
- **Android APK/AAB:** GitHub Actions with `setup-java` + `cache-gradle` + `flutter build appbundle` → upload to internal testing track.
- **iOS:** Xcode Cloud or Codemagic (both have free tiers) → automate `flutter build ios` → TestFlight.
- **Slack notify** on success via the webhook plugin already present (`app/core/webhooks.py`).

---

## Known limitations

- The **barcode input** widget (`lib/core/apex_barcode_input.dart`) currently targets USB/Bluetooth HID scanners. Device-camera scanning needs `mobile_scanner` or `barcode_scan2` + Android/iOS permission declarations.
- **PWA offline queue** (`lib/core/apex_offline_queue.dart`) uses SharedPreferences, which works on all platforms but has a ~1 MB soft limit. For >1 MB queue depth use `sqflite` instead.
- **ApexRecentItems** uses `dart:html` localStorage — it no-ops cleanly on mobile, but for mobile persistence switch to `SharedPreferences`.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Gradle build failed` on Android | Delete `~/.gradle/caches` and rerun `flutter clean && flutter build apk` |
| iOS pods out of sync | `cd ios && pod deintegrate && pod install && cd ..` |
| "No connected device" | `flutter devices` to list; `flutter emulators --launch <id>` for Android |
| RTL flipped wrong | Check the widget is inside the root `Directionality` — all screens in `lib/app/apex_app.dart` are wrapped |

---

Updated: 2026-04-17 — Sprint 44
