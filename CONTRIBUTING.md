# Contributing — READ THIS BEFORE PUSHING

## The rules (enforced by the repo, not by trust)
1. **Never push to `main`.** It is protected — direct pushes are rejected.
2. Work on a branch: `git checkout -b feature/short-name`
3. Push your branch and open a **Pull Request**.
4. The **CI must be green** (`flutter analyze` — catches anything that
   won't compile). Red CI = merge button locked.
5. One approving review required before merge.

## Before you open a PR
```bash
flutter pub get
flutter analyze     # must show no errors
```
Ideally also run the app once on a device/emulator.

## Ground rules
- The `android/` and `ios/` folders are NOT in the repo — generate them
  locally with `flutter create . --platforms=android,ios --org com.myassistant`,
  then apply the build.gradle.kts + AndroidManifest changes from
  PROJECT_STATUS.md. NEVER commit these folders.
- Never commit secrets or dart-define values.
- Don't touch pubspec version pins (especially flutter_local_notifications
  ">=19.0.0 <20.0.0" and timezone ^0.10) without reading PROJECT_STATUS.md —
  they are pinned because other versions break the build.
- Update PROJECT_STATUS.md in the same PR as your change.
