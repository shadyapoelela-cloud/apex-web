# APEX Fastlane — Mobile Release Automation

This directory is the single source of truth for everything needed to
ship the APEX Flutter app to Google Play and the Apple App Store.

## Files

| Path | What it is |
|------|------------|
| `Fastfile` | Lane definitions (build_release, testflight, play_internal) |
| `Appfile`  | Bundle ids + team ids (reads from ENV — no secrets committed) |
| `metadata/android/{en-US,ar}/` | Play Console listing (title + short + full description) |
| `metadata/ios/en-US/` | App Store Connect listing (description + keywords) |

## First-time setup

1. **Install fastlane** on your CI + dev machine:
   ```bash
   brew install fastlane        # macOS
   sudo gem install fastlane    # Linux / manual
   ```

2. **Android signing** — generate the keystore once:
   ```bash
   cd apex_finance/android
   keytool -genkey -v -keystore apex-release-key.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias apex-key
   ```
   Then create `android/key.properties` (git-ignored):
   ```properties
   storePassword=***
   keyPassword=***
   keyAlias=apex-key
   storeFile=/absolute/path/to/apex-release-key.jks
   ```
   See `apex_finance/MOBILE_BUILD.md` for the Gradle wiring.

3. **Play Console service account** — create a service account in Google
   Cloud, grant it Play Console access, download the JSON:
   ```bash
   export GOOGLE_PLAY_JSON_KEY_FILE=/secure/path/play-console-key.json
   ```

4. **iOS signing** — sign in to Xcode with your Apple Developer account.
   Set the team id + bundle id in env vars:
   ```bash
   export APPLE_ID=you@example.com
   export APPLE_TEAM_ID=ABCDE12345
   export IOS_BUNDLE_ID=com.apexfinance.apex
   ```

## Daily use

```bash
# From apex_finance/

# Android — signed AAB + upload to Play internal testing track
fastlane android play_internal

# iOS — archive + upload to TestFlight
fastlane ios testflight

# Just build (no upload) — useful for smoke testing
fastlane android build_release
fastlane ios build_release
```

## Listing metadata

### Updating descriptions

Edit the .txt files under `metadata/<platform>/<locale>/`. Next
`play_internal` / `testflight` run pushes them. If you skip upload, the
files still serve as documentation of what was last sent.

### Localization

- Android: add sibling folders — `metadata/android/ar/`,
  `metadata/android/fr-FR/`, etc. Already includes `en-US` + `ar`.
- iOS: ditto under `metadata/ios/`.

### Screenshots

Drop PNGs into `metadata/<platform>/<locale>/images/`. Required sizes:
- Android: `phoneScreenshots/`, `tenInchScreenshots/`, `sevenInchScreenshots/`
- iOS: `6.5-inch/`, `5.5-inch/`, `12.9-inch/`

Fastlane uploads them automatically during the lane runs.

## App icons

Replace the default Flutter icons with APEX branding using
[flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons).
Add to `pubspec.yaml` once:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.1

flutter_launcher_icons:
  android: "ic_launcher"
  ios: true
  image_path: "assets/icon/apex_logo_1024.png"
  adaptive_icon_background: "#0A2540"
  adaptive_icon_foreground: "assets/icon/apex_logo_foreground.png"
```

Then:
```bash
dart run flutter_launcher_icons
```

## CI integration

GitHub Actions example (place in `.github/workflows/release-mobile.yml`):

```yaml
name: Release mobile
on:
  workflow_dispatch:
    inputs:
      target:
        type: choice
        options: [play_internal, testflight]

jobs:
  release:
    runs-on: ${{ inputs.target == 'testflight' && 'macos-latest' || 'ubuntu-latest' }}
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.24' }
      - uses: ruby/setup-ruby@v1
        with: { ruby-version: '3.3' }
      - run: gem install fastlane
      - name: Decrypt secrets
        run: |
          echo "$PLAY_JSON_B64"  | base64 -d > fastlane/play-console-key.json
          echo "$ANDROID_KS_B64" | base64 -d > android/apex-release-key.jks
      - working-directory: apex_finance
        run: fastlane ${{ github.event.inputs.target == 'testflight' && 'ios testflight' || 'android play_internal' }}
        env:
          GOOGLE_PLAY_JSON_KEY_FILE: ../fastlane/play-console-key.json
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `key.properties not found` | Create the file as described in step 2 |
| `Certificate has expired` (iOS) | Re-generate via Xcode → Signing & Capabilities → Automatically manage signing |
| Play upload: `Package not found` | Check `ANDROID_PACKAGE_NAME` matches your Play app |
| iOS upload: `Missing entitlement` | Enable Push Notifications + Background Fetch in App Store Connect capabilities |

## Gitignored paths

These must never be committed:
```
fastlane/play-console-key.json
android/apex-release-key.jks
android/key.properties
ios/fastlane/report.xml
ios/fastlane/Preview.html
ios/fastlane/screenshots
```

All already listed in `apex_finance/.gitignore` by default or should
be added there on first use.
