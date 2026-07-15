plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

android {
    namespace = "com.myassistant.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.myassistant.app"
        minSdk = 29            // Android 10+, per contract Section 2
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"

        // Backend base URL — point to your India-hosted server later.
        buildConfigField("String", "BASE_URL", "\"https://api.myassistant.example.com\"")

        // From Google Cloud Console → Credentials → OAuth 2.0 Client IDs → *Web* client.
        // (Yes, the WEB client ID — that's what Credential Manager and the backend both use.)
        buildConfigField("String", "GOOGLE_WEB_CLIENT_ID", "\"YOUR_WEB_CLIENT_ID.apps.googleusercontent.com\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.09.03")
    implementation(composeBom)

    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.6")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.6")
    implementation("androidx.activity:activity-compose:1.9.2")

    // Compose UI + Material 3 (matches the UI design doc)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")

    // Networking — talks only to YOUR backend; AI keys never live in the app
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")

    // Google Play In-App Updates (F1 update flow once live on Play Store)
    implementation("com.google.android.play:app-update:2.1.0")
    implementation("com.google.android.play:app-update-ktx:2.1.0")

    // DataStore for cached remote config / feature flags
    implementation("androidx.datastore:datastore-preferences:1.1.1")

    // Google Sign-In (F1) via Credential Manager — the modern, non-deprecated API
    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")
}
