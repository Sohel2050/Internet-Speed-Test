allprojects {
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

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()

rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory =
        newBuildDir.dir(project.name)

    project.layout.buildDirectory.value(
        newSubprojectBuildDir
    )
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}