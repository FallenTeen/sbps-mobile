import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Dibaca dari android/key.properties (di CI dibuat otomatis oleh Codemagic
// dari environment variable terenkripsi; secara lokal opsional).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.sbps.sbps_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Diisi ulang per flavor di bawah.
        applicationId = "com.sbps.presensi"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Satu codebase -> dua aplikasi terpisah (applicationId berbeda).
    flavorDimensions += "app"
    productFlavors {
        create("presensi") {
            dimension = "app"
            applicationId = "com.sbps.presensi"
            resValue("string", "app_name", "SBPS Presensi")
        }
        create("proyek") {
            dimension = "app"
            applicationId = "com.sbps.proyek"
            resValue("string", "app_name", "SBPS Proyek")
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Tanpa key.properties (lokal) fallback ke debug key agar
            // `flutter build apk --release` tetap bisa diuji.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
