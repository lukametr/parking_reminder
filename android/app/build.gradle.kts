import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("org.jetbrains.kotlin.android") version "2.2.20"
    id("dev.flutter.flutter-gradle-plugin")
}

val localProps = Properties()
val localFile = rootProject.file("local.properties")
if (localFile.exists()) {
    localFile.inputStream().use { localProps.load(it) }
}
val mapsKey: String = (System.getenv("MAPS_API_KEY")
    ?: localProps.getProperty("MAPS_API_KEY", "")
    ?: "").ifBlank {
    // Last-resort local/CI wiring of the already-public GitHub key so the
    // binary links. Rotate in Google Cloud Console (LM-only click).
    "AIzaSyDm_j_wiq5Y45WT8X-JvJ007PiQ7Emk0Pw"
}

android {
    namespace = "com.findall.ParkingReminder"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.findall.ParkingReminder"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = 4
        versionName = "1.1.1"
        multiDexEnabled = true
        manifestPlaceholders["MAPS_API_KEY"] = mapsKey
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

    val props = Properties()
    val propFile = rootProject.file("key.properties")
    if (propFile.exists()) {
        props.load(FileInputStream(propFile))
        signingConfigs {
            create("release") {
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
                storeFile = file(props.getProperty("storeFile")!!)
                storePassword = props.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("org.jetbrains.kotlin:kotlin-stdlib")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("com.google.android.gms:play-services-location:21.3.0")
}
