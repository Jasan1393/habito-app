plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

import java.util.Properties

fun truthy(value: String?): Boolean {
    return value?.trim()?.lowercase() in setOf("1", "true", "yes", "y", "on", "si")
}

val keystoreProperties = Properties()
val configuredKeystorePropertiesPath = providers.gradleProperty("HABITO_KEY_PROPERTIES_FILE").orNull
    ?: System.getenv("HABITO_KEY_PROPERTIES_FILE")
val keystorePropertiesFile = if (!configuredKeystorePropertiesPath.isNullOrBlank()) {
    file(configuredKeystorePropertiesPath)
} else {
    rootProject.file("key.properties")
}
val hasReleaseKeystore = keystorePropertiesFile.exists()
val requestedReleaseBuild = gradle.startParameter.taskNames.any {
    val task = it.lowercase()
    task.contains("release") || task.contains("bundle")
}

if (requestedReleaseBuild && !hasReleaseKeystore) {
    error(
        "Release signing is not configured. Create android/key.properties " +
            "from android/key.properties.example before building for Google Play."
    )
}

if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val configuredKeystorePath = providers.gradleProperty("HABITO_KEYSTORE_FILE").orNull
    ?: System.getenv("HABITO_KEYSTORE_FILE")

val facebookAppId = providers.gradleProperty("FACEBOOK_APP_ID").orNull
    ?: System.getenv("FACEBOOK_APP_ID")
    ?: "13459473576995552"
val facebookClientToken = providers.gradleProperty("FACEBOOK_CLIENT_TOKEN").orNull
    ?: System.getenv("FACEBOOK_CLIENT_TOKEN")
    ?: "c4803e6b72a71152099e736c2f90bae8"
val facebookEventsEnabled = truthy(
    providers.gradleProperty("HABITO_FACEBOOK_EVENTS_ENABLED").orNull
        ?: System.getenv("HABITO_FACEBOOK_EVENTS_ENABLED")
        ?: "true"
)
val facebookAdTrackingEnabled = truthy(
    providers.gradleProperty("HABITO_FACEBOOK_AD_TRACKING_ENABLED").orNull
        ?: System.getenv("HABITO_FACEBOOK_AD_TRACKING_ENABLED")
        ?: "true"
)
val facebookLoginProtocolScheme = if (facebookAppId.isNotBlank()) {
    "fb$facebookAppId"
} else {
    "fb"
}
val tiktokAppId = providers.gradleProperty("TIKTOK_APP_ID").orNull
    ?: System.getenv("TIKTOK_APP_ID")
    ?: "7645715146475700242"
val tiktokPackageAppId = providers.gradleProperty("TIKTOK_PACKAGE_APP_ID").orNull
    ?: System.getenv("TIKTOK_PACKAGE_APP_ID")
    ?: "com.habitobarberia.app"
val tiktokAccessToken = providers.gradleProperty("TIKTOK_ACCESS_TOKEN").orNull
    ?: System.getenv("TIKTOK_ACCESS_TOKEN")
    ?: keystoreProperties.getProperty("tiktokAccessToken")
    ?: ""
val tiktokEventsEnabled = truthy(
    providers.gradleProperty("HABITO_TIKTOK_EVENTS_ENABLED").orNull
        ?: System.getenv("HABITO_TIKTOK_EVENTS_ENABLED")
        ?: "true"
)
val tiktokAdTrackingEnabled = truthy(
    providers.gradleProperty("HABITO_TIKTOK_AD_TRACKING_ENABLED").orNull
        ?: System.getenv("HABITO_TIKTOK_AD_TRACKING_ENABLED")
        ?: "true"
)

android {
    namespace = "com.habitobarberia.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // Necesario para flutter_local_notifications y otras libs modernas
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.habitobarberia.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue("string", "facebook_app_id", facebookAppId)
        resValue("string", "facebook_client_token", facebookClientToken)
        resValue("string", "fb_login_protocol_scheme", facebookLoginProtocolScheme)
        resValue("string", "tiktok_app_id", tiktokAppId)
        resValue("string", "tiktok_package_app_id", tiktokPackageAppId)
        resValue("string", "tiktok_access_token", tiktokAccessToken)
        resValue("string", "tiktok_events_enabled", tiktokEventsEnabled.toString())
        resValue("string", "tiktok_ad_tracking_enabled", tiktokAdTrackingEnabled.toString())
        manifestPlaceholders["facebookAutoInitEnabled"] = facebookEventsEnabled.toString()
        manifestPlaceholders["facebookAutoLogEnabled"] = facebookEventsEnabled.toString()
        manifestPlaceholders["facebookAdTrackingEnabled"] = facebookAdTrackingEnabled.toString()
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                val configuredStoreFile = configuredKeystorePath
                    ?: (keystoreProperties["storeFile"] as String)
                storeFile = file(configuredStoreFile)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    implementation("androidx.activity:activity-ktx:1.10.1")
    implementation("com.github.tiktok:tiktok-business-android-sdk:1.5.0")
    implementation("androidx.lifecycle:lifecycle-process:2.3.1")
    implementation("androidx.lifecycle:lifecycle-common-java8:2.3.1")
    implementation("com.android.installreferrer:installreferrer:2.2")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
