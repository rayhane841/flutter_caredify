plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // ✅ AJOUTEZ CETTE LIGNE POUR FIREBASE :
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.caredify"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID
        applicationId = "com.example.caredify"  // ✅ Doit correspondre à Firebase Console
        // You can update the following values to match your application needs.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// ✅ AJOUTEZ CE BLOC À LA FIN DU FICHIER (optionnel mais recommandé) :
dependencies {
    // Firebase BoM (Bill of Materials) pour gérer les versions
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    
    // Firebase dependencies (FlutterFire gère automatiquement, mais utile pour d'autres modules)
    // implementation("com.google.firebase:firebase-auth")
    // implementation("com.google.firebase:firebase-firestore")
}