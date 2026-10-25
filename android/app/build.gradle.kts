import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val uploadProperties = Properties()
val uploadPropertiesFile = rootProject.file("key.properties")
if (uploadPropertiesFile.exists()) {
    uploadPropertiesFile.inputStream().use { uploadProperties.load(it) }
}

val triviaSplitAbi = project.findProperty("split-per-abi")?.toString()?.toBoolean() ?: false
if (!triviaSplitAbi) {
    // Filtrar también las bibliotecas JNI de plugins por el destino real.
    extra["disable-abi-filtering"] = true
}

android {
    namespace = "ar.maillet.triviaantiguedad"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        if (!triviaSplitAbi) {
            val destinos = (project.findProperty("target-platform")?.toString()
                ?: "android-arm,android-arm64,android-x64").split(",")
            val arquitecturas = mapOf("android-arm" to "armeabi-v7a", "android-arm64" to "arm64-v8a", "android-x64" to "x86_64")
            ndk {
                abiFilters.clear()
                abiFilters.addAll(destinos.map { arquitecturas.getValue(it) })
            }
        }
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ar.maillet.triviaantiguedad"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (uploadPropertiesFile.exists()) {
                storeFile = file(uploadProperties.getProperty("storeFile"))
                storePassword = uploadProperties.getProperty("storePassword")
                keyAlias = uploadProperties.getProperty("keyAlias")
                keyPassword = uploadProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    // Distribución directa por APK: las bibliotecas se extraen al instalar.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
