import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// Google Services / Firebase
// Only applied when google-services.json exists.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(
        FileInputStream(keystorePropertiesFile)
    )
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")

if (localPropertiesFile.exists()) {
    localProperties.load(
        FileInputStream(localPropertiesFile)
    )
}

android {
    namespace = "com.albonik.speedtest"

    compileSdk = 36

    ndkVersion =
        localProperties["ndk.version"]?.toString()
            ?: "29.0.14206865"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.albonik.speedtest"

        minSdk = maxOf(
            flutter.minSdkVersion,
            23
        )

        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias =
                    keystoreProperties["keyAlias"] as String

                keyPassword =
                    keystoreProperties["keyPassword"] as String

                storeFile =
                    keystoreProperties["storeFile"]
                        ?.let { file(it) }

                storePassword =
                    keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (keystorePropertiesFile.exists()) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }

            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile(
                    "proguard-android-optimize.txt"
                ),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        )
    }
}

flutter {
    source = "../.."
}

dependencies {

    // Google Play Services
    implementation(
        "com.google.android.gms:play-services-appset:16.0.2"
    )

    implementation(
        "com.google.android.gms:play-services-ads-identifier:18.0.1"
    )

    implementation(
        "com.google.android.gms:play-services-basement:18.3.0"
    )

    /*
     * Unity LevelPlay mediation dependencies are intentionally
     * NOT hard-coded here.
     *
     * The unity_levelplay_mediation Flutter plugin manages
     * its mediation dependencies.
     */
}