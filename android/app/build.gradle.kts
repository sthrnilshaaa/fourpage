import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: android/key.properties (git-ignored; CI writes it from
// secrets) with storeFile, storePassword, keyAlias, keyPassword. Without it,
// release builds are signed with the debug key so `flutter run --release`
// still works locally.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.fourpages.reader"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.fourpages.reader"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Two builds of the same app (same id, so one can update the other's data):
    //   github    - sideloaded APKs from GitHub Releases; updates itself by
    //               downloading the newer release APK (see AppUpdater.kt).
    //   playstore - the Play Store build; updates through Google Play's
    //               in-app update flow.
    // `flutter build apk --flavor github|playstore`; plain `flutter run`
    // uses default-flavor from pubspec.yaml.
    flavorDimensions += "store"
    productFlavors {
        create("github") {
            dimension = "store"
        }
        create("playstore") {
            dimension = "store"
        }
    }

    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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

dependencies {
    implementation(project(":reader"))
    "playstoreImplementation"("com.google.android.play:app-update:2.1.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
