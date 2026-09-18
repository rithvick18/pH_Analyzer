import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingFile = rootProject.file("key.properties")
if (signingFile.exists()) signingFile.inputStream().use { signingProperties.load(it) }
val releaseApplicationId = providers.environmentVariable("PH_APPLICATION_ID").orNull
val unsignedValidation = providers.environmentVariable("PH_UNSIGNED_VALIDATION").orNull == "true"
val hasReleaseSigning = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !signingProperties.getProperty(it).isNullOrBlank() }

android {
    namespace = "com.example.ph_analyzer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }
    defaultConfig {
        applicationId = releaseApplicationId ?: "com.example.ph_analyzer"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        if (hasReleaseSigning) {
            create("production") {
                storeFile = rootProject.file(signingProperties.getProperty("storeFile"))
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        release {
            signingConfig = if (!unsignedValidation && hasReleaseSigning) signingConfigs.getByName("production") else null
        }
    }
}

// Compile-only CI builds may be unsigned. Normal release builds must never use debug keys.
val validateProductionRelease = tasks.register("validateProductionRelease") {
    doLast {
        if (!unsignedValidation) {
            check(!releaseApplicationId.isNullOrBlank() && !releaseApplicationId.startsWith("com.example.")) {
                "Set PH_APPLICATION_ID to your registered production application ID."
            }
            check(hasReleaseSigning) { "Configure android/key.properties with your production signing key." }
        }
    }
}
tasks.configureEach {
    if (name == "preReleaseBuild") dependsOn(validateProductionRelease)
}
flutter { source = "../.." }
