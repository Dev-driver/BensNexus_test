plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Ajout du plugin Google Services pour Firebase
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.bensnexus"
    compileSdk = flutter.compileSdkVersion
    // Forcer la version du NDK requise par les plugins Firebase.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.bensnexus"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // La plupart des SDK Firebase nécessitent une version minimale de 21.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Active le multidex, souvent nécessaire avec les bibliothèques Firebase.
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Importer la Bill of Materials (BOM) de Firebase pour gérer les versions des dépendances.
    // Utilise la dernière version disponible pour une meilleure compatibilité.
    implementation(platform("com.google.firebase:firebase-bom:33.2.0"))

    // Ajouter les dépendances pour les produits Firebase que vous souhaitez utiliser.
    // Pas besoin de spécifier de version, la BOM s'en occupe.
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    // Ajoutez ici d'autres dépendances Firebase (ex: "com.google.firebase:firebase-firestore")
}
