// build.gradle.kts (Module: android/app)

import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.findall.ParkingReminder"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.findall.ParkingReminder"
        minSdk = 23
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    // Загрузка ключей подписи из key.properties
    val props = Properties()
    val propFile = rootProject.file("key.properties")
    if (propFile.exists()) {
        props.load(FileInputStream(propFile))
        signingConfigs {
            create("release") {
                // Читаем именно те ключи, которые должны быть в key.properties
                keyAlias     = props.getProperty("keyAlias")
                keyPassword  = props.getProperty("keyPassword")
                storeFile    = file(props.getProperty("storeFile")!!)
                storePassword= props.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.findByName("release")
        }
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    lint {
        baseline = file("lint-baseline.xml")
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")
    implementation("androidx.multidex:multidex:2.0.1")
}
