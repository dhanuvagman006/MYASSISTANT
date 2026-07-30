#!/usr/bin/env bash
# Fix "compile against version 34 or later" AAR metadata errors
# by forcing compileSdk 36 on the app and all Flutter plugins.
# Run from your Flutter project root:  bash fix_android_build.sh
set -e

if [ ! -d android ]; then
  echo "ERROR: no android/ folder here. Run this from your Flutter project root."
  exit 1
fi

# ---- 1. Project-level gradle: force compileSdk 36 on every plugin ----
if [ -f android/build.gradle.kts ]; then
  if ! grep -q "compileSdkVersion(36)" android/build.gradle.kts; then
    cat >> android/build.gradle.kts <<'EOF'

// Force all plugin subprojects onto a modern compileSdk
subprojects {
    afterEvaluate {
        if (project.extensions.findByName("android") != null) {
            project.extensions.configure<com.android.build.gradle.BaseExtension>("android") {
                compileSdkVersion(36)
            }
        }
    }
}
EOF
    echo "Patched android/build.gradle.kts"
  else
    echo "android/build.gradle.kts already patched"
  fi
elif [ -f android/build.gradle ]; then
  if ! grep -q "compileSdkVersion 36" android/build.gradle; then
    cat >> android/build.gradle <<'EOF'

// Force all plugin subprojects onto a modern compileSdk
subprojects {
    afterEvaluate { project ->
        if (project.hasProperty('android')) {
            project.android {
                compileSdkVersion 36
            }
        }
    }
}
EOF
    echo "Patched android/build.gradle"
  else
    echo "android/build.gradle already patched"
  fi
fi

# ---- 2. App-level gradle: bump the app's own compileSdk ----
for f in android/app/build.gradle.kts android/app/build.gradle; do
  [ -f "$f" ] || continue
  sed -i -E 's/compileSdk = flutter\.compileSdkVersion/compileSdk = 36/' "$f"
  sed -i -E 's/compileSdkVersion flutter\.compileSdkVersion/compileSdkVersion 36/' "$f"
  sed -i -E 's/compileSdk = 3[0-5]\b/compileSdk = 36/' "$f"
  echo "Checked $f"
done

# ---- 3. Allow plain-http to your local backend (dev only) ----
MANIFEST=android/app/src/main/AndroidManifest.xml
if [ -f "$MANIFEST" ] && ! grep -q usesCleartextTraffic "$MANIFEST"; then
  sed -i 's/<application/<application android:usesCleartextTraffic="true"/' "$MANIFEST"
  echo "Enabled cleartext HTTP in AndroidManifest.xml (dev only — remove before release)"
fi

echo
echo "Done. Now run:"
echo "  flutter clean && flutter pub get"
echo "  flutter run --dart-define=BASE_URL=http://10.161.195.39:3000"
