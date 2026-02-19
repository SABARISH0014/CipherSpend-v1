plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.cipherspend"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    // --- FIX: All the blocks below MUST stay inside the 'android' braces ---

    androidResources {
        noCompress.addAll(listOf("tflite", "lite"))
    }

    defaultConfig {
        applicationId = "com.example.cipherspend"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86_64"))
        }
    }

    buildTypes {
        // Use getByName for release in Kotlin DSL
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
} // <--- This brace now correctly closes the entire 'android' section

flutter {
    source = "../.."
}