plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.github.artur_rios.orpheus"
    // 37 rather than Flutter's own default, which is 36 as of Flutter 3.47:
    // `permission_handler_android` is built against 37 and refuses to be
    // consumed by anything compiled against less, so the build fails outright
    // without this. Compiling against a newer platform is not the same as
    // running on one — `targetSdk` is what opts this application in to new
    // runtime behaviour, and `minSdk` is what decides where it installs, and
    // neither of those moves here.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.artur_rios.orpheus"
        // 24 — Android 7 — and stated here rather than left to
        // `flutter.minSdkVersion`, because this floor is the plugins' and not
        // Flutter's, and a number that moves when the toolchain moves is a
        // number the README cannot promise.
        //
        // The engine, media_kit, needs 23. Three plugins need 24 —
        // permission_handler_android, shared_preferences_android and
        // audio_session — and the highest floor is the floor. Writing 23 here
        // does not lower it: the Flutter tool rewrites this line on the next
        // Android build, which is how the discrepancy stayed invisible until
        // the built package was read back.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
