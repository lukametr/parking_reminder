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
// Env or android/local.properties only — never commit a key.
val mapsKey: String = (System.getenv("MAPS_API_KEY")
    ?: localProps.getProperty("MAPS_API_KEY", "")
    ?: "").trim()

android {
    namespace = "com.lukacode.sosapp"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.lukacode.sosapp"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 20
        versionName = "1.1.14"
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
    val hasUploadSigning = propFile.exists()
    if (hasUploadSigning) {
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
            // R8 on → Play deobfuscation/mapping.txt for Closed testing upload.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // Only attach signing when present. Fail-closed for *release* tasks is
            // enforced below — do NOT check() here: root evaluationDependsOn(":app")
            // evaluates this block during `assembleDebug` on CI (no key.properties).
            if (hasUploadSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

// Fail release packaging without upload keystore; leave debug CI green.
gradle.taskGraph.whenReady {
    val releasing = allTasks.any { task ->
        val n = task.name
        n == "assembleRelease" ||
            n == "bundleRelease" ||
            n.startsWith("assembleRelease") ||
            n.startsWith("bundleRelease")
    }
    if (releasing && !rootProject.file("key.properties").exists()) {
        throw GradleException(
            "Missing android/key.properties (and upload keystore). " +
                "Release builds must use Play upload signing — copy key.properties.example " +
                "to key.properties and set storeFile/passwords. Debug builds are unchanged.",
        )
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
