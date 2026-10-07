pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()

            file("local.properties")
                .inputStream()
                .use { properties.load(it) }

            val flutterSdkPath =
                properties.getProperty("flutter.sdk")

            require(flutterSdkPath != null) {
                "flutter.sdk not set in local.properties"
            }

            flutterSdkPath
        }

    includeBuild(
        "$flutterSdkPath/packages/flutter_tools/gradle"
    )

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()

        // Chartboost
        maven {
            url = uri(
                "https://cboost.jfrog.io/artifactory/chartboost-ads/"
            )
        }

        // Mintegral / MBridge
        maven {
            url = uri(
                "https://dl-maven-android.mintegral.com/repository/mbridge_android_sdk_oversea/"
            )
        }
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(
        RepositoriesMode.PREFER_SETTINGS
    )

    repositories {
        google()
        mavenCentral()

        // Flutter
        maven {
            url = uri(
                "https://storage.googleapis.com/download.flutter.io"
            )
        }

        // Chartboost
        maven {
            url = uri(
                "https://cboost.jfrog.io/artifactory/chartboost-ads/"
            )
        }

        // Mintegral / MBridge
        maven {
            url = uri(
                "https://dl-maven-android.mintegral.com/repository/mbridge_android_sdk_oversea/"
            )
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"

    id("com.android.application") version "9.1.0" apply false

    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")