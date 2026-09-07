plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.krishidoc.krishidoc_app"
    // tflite_flutter 0.12 compiles against the Android 36 APIs. This controls
    // the build toolchain only; minSdk below remains the device compatibility
    // floor.
    compileSdk = 36
    // Pinned rather than inherited: sqlite3_flutter_libs requires this NDK,
    // and the Flutter default trails it, which the release build warns about.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Final id pending the trademark check (audit L-3, PROJECT_MEMORY open question).
        // Real-device audits must not replace or uninstall the farmer's app.
        val modelAudit = providers.gradleProperty("target").orNull
            ?.contains("labelled_model_audit") == true
        val v7Audit = providers.gradleProperty("target").orNull
            ?.contains("labelled_model_audit_v7") == true
        val v7Test = providers.gradleProperty("target").orNull
            ?.contains("main_potato_v7") == true
        applicationId = if (v7Audit) "com.krishidoc.app.v7audit"
            else if (v7Test) "com.krishidoc.app.v7test"
            else if (modelAudit) "com.krishidoc.app.modelaudit" else "com.krishidoc.app"
        manifestPlaceholders["appLabel"] = if (v7Audit) "KrishiDoc V7 Audit"
            else if (v7Test) "KrishiDoc V7 Test"
            else if (modelAudit) "KrishiDoc Model Audit" else "KrishiDoc"
        // The official TensorFlow Lite Flutter runtime requires Android 8.0.
        // Keeping API 23 here would produce an APK that installs but cannot
        // load the disease model on Android 6/7 devices.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
