import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.isFile
val allowDebugReleaseSigning =
    (System.getenv("ALLOW_DEBUG_RELEASE_SIGNING") ?: "")
        .lowercase()
        .let { it == "true" || it == "1" }

if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
    val requiredKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    val missingKeys = requiredKeys.filter { keystoreProperties.getProperty(it).isNullOrBlank() }
    check(missingKeys.isEmpty()) {
        "android/key.properties is missing: ${missingKeys.joinToString()}"
    }
}

android {
    namespace = "com.algive.jizhang_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.algive.jizhang_app"
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
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else if (allowDebugReleaseSigning) {
                // Explicit local acceptance mode only. Production release tasks
                // fail below when no private keystore is configured.
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    implementation("androidx.core:core:1.18.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}


tasks.matching { it.name == "assembleRelease" || it.name == "bundleRelease" }
    .configureEach {
        doFirst {
            check(hasReleaseKeystore || allowDebugReleaseSigning) {
                "Production Android Release requires android/key.properties and a private keystore. " +
                    "For local performance/acceptance testing only, set ALLOW_DEBUG_RELEASE_SIGNING=true explicitly."
            }
        }
    }
