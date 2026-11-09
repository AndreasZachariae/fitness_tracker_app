import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (SPEC §3): ../.secrets/key.properties relative to android/; storeFile is relative to .secrets/.
// Never fall back to the debug key for release builds.
val keystorePropertiesFile = rootProject.file("../.secrets/key.properties")
val keystoreProperties =
    Properties().apply {
        if (keystorePropertiesFile.exists()) {
            keystorePropertiesFile.inputStream().use { load(it) }
        }
    }

android {
    // Never change namespace/applicationId: the installed release app with real data depends on it.
    namespace = "de.gymlog.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (1.2.0).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "de.gymlog.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Native libraries of packages (sqlite3, jni) only for the platforms Flutter builds, e.g. arm64 only
        // with --target-platform android-arm64 (scripts/build-release-apk.sh, ~23 MB instead of ~70 MB).
        // The Flutter Gradle plugin always lists all three ABIs; it runs before this block.
        val abiOf = mapOf("android-arm" to "armeabi-v7a", "android-arm64" to "arm64-v8a", "android-x64" to "x86_64")
        (project.findProperty("target-platform") as String?)
            ?.split(",")
            ?.mapNotNull { abiOf[it.trim()] }
            ?.takeIf { it.isNotEmpty() }
            ?.let { abis ->
                ndk {
                    abiFilters.clear()
                    abiFilters.addAll(abis)
                }
            }
    }

    buildFeatures {
        resValues = true
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = File(keystorePropertiesFile.parentFile, keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            // Separate DEV app with its own data; signed with the default debug keystore in ~/.android.
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "GymLog DEV")
        }
        // The Flutter Gradle plugin creates "profile" via initWith(debug) before this block runs,
        // so it would not inherit the suffix. Keep it a DEV app, never the real one.
        maybeCreate("profile").apply {
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "GymLog DEV")
        }
        release {
            resValue("string", "app_name", "GymLog")
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

val verifyReleaseSigning by tasks.registering {
    description = "Fails release builds when the release signing key is missing."
    val propertiesFile = keystorePropertiesFile
    doFirst {
        if (!propertiesFile.exists()) {
            throw GradleException(
                "Signaturschlüssel fehlt – siehe README, Schritt 4 (erwartet: ${propertiesFile.absolutePath})",
            )
        }
    }
}

tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(verifyReleaseSigning)
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
    // Java time APIs on older Android for flutter_local_notifications (1.2.0).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
