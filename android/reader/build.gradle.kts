plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.fourpages.reader.nativereader"
    compileSdk = 37

    defaultConfig {
        minSdk = 24
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Readium 3.4.0 uses java.time APIs below API 26.
        isCoreLibraryDesugaringEnabled = true
    }

    // Sample books (repo root test-books/) are bundled into the test APK only.
    sourceSets["androidTest"].assets.srcDirs("../../test-books")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    val readium = "3.4.0"
    implementation("org.readium.kotlin-toolkit:readium-shared:$readium")
    implementation("org.readium.kotlin-toolkit:readium-streamer:$readium")
    implementation("org.readium.kotlin-toolkit:readium-navigator:$readium")
    implementation("org.jsoup:jsoup:1.23.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // androidx.core 1.19 (pulled in by Readium) requires AGP 9.1; this build is on 9.0.1. A Flutter plugin needs 1.18.
    constraints {
        implementation("androidx.core:core:1.18.0") { version { strictly("1.18.0") } }
        implementation("androidx.core:core-ktx:1.18.0") { version { strictly("1.18.0") } }
    }

    testImplementation("junit:junit:4.13.2")

    androidTestImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test:rules:1.7.0")
    androidTestImplementation("androidx.appcompat:appcompat:1.8.0")
    androidTestImplementation("androidx.fragment:fragment-ktx:1.9.0")
    androidTestImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.11.0")
}
