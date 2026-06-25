plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {

    namespace = "com.example.binsort_new"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    aaptOptions {
        noCompress += "tflite"
    }

    androidResources {
        noCompress.add("tflite")
        noCompress.add("lite")
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.binsort_new"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        ndk {
            abiFilters += listOf(
                "arm64-v8a",
                "armeabi-v7a",
                "x86_64"
            )
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")

            isMinifyEnabled = false
            isShrinkResources = false

            ndk {
                debugSymbolLevel = "FULL"
            }
        }
    }
}

// เพิ่มบรรทัดนี้เพื่อให้ Flutter หา APK เจอ
project.buildDir = file("../../build/app")

flutter {
    source = "../.."
}