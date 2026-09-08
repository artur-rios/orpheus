import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The release signing material, if this machine holds any.
//
// Two sources, environment first. The release workflow passes the keystore and
// its passwords as environment variables, where a password holding a backslash
// or a colon survives intact — `key.properties` is a Java properties file, in
// which both of those are escapes, and a mangled password fails as a wrong one.
// A developer's own machine uses that file instead, which is what Flutter
// documents and what `android/.gitignore` already refuses to commit.
//
// Neither present is not an error: the release build falls back to the debug
// key, so `flutter build apk --release` still works for anyone who only wants
// to run the thing. What that costs is the reason the release workflow reads
// the signer back out of the package it is about to publish rather than
// trusting this file — a debug-signed release cannot be installed over the
// previous one, and the owner meets that as "App not installed".
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use(::load)
}

fun signingValue(variable: String, property: String): String? =
    (System.getenv(variable) ?: keystoreProperties.getProperty(property))
        ?.takeIf(String::isNotBlank)

val keystorePath = signingValue("ORPHEUS_KEYSTORE", "storeFile")
val releaseStorePassword = signingValue("ORPHEUS_KEYSTORE_PASSWORD", "storePassword")
val releaseKeyAlias = signingValue("ORPHEUS_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = signingValue("ORPHEUS_KEY_PASSWORD", "keyPassword")

// Half a configuration is a mistake, not a choice, and falling quietly back to
// the debug key is exactly how an unupgradable package gets published. Said
// here, where the four values are, rather than left to surface as a signing
// failure or — worse — as no failure at all.
val provided = listOfNotNull(
    keystorePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
)
require(provided.isEmpty() || provided.size == 4) {
    "The release signing configuration is incomplete: give all four of " +
        "ORPHEUS_KEYSTORE, ORPHEUS_KEYSTORE_PASSWORD, ORPHEUS_KEY_ALIAS and " +
        "ORPHEUS_KEY_PASSWORD (or storeFile, storePassword, keyAlias and " +
        "keyPassword in android/key.properties), or none of them."
}

val releaseKeystore = keystorePath?.let(rootProject::file)
require(releaseKeystore == null || releaseKeystore.exists()) {
    "The release keystore was named but is not there: $releaseKeystore"
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

    signingConfigs {
        if (releaseKeystore != null) {
            create("release") {
                storeFile = releaseKeystore
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // The debug key where there is no release one — see the note above
            // the properties. Every published package is checked for which of
            // the two it actually got.
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
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
