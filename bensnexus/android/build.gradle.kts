buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // La version la plus récente au moment de la rédaction est 4.4.2
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Redirige le répertoire de build du projet Android vers le répertoire de build racine de Flutter.
// Cela centralise les artefacts de build.
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    // Redirige le répertoire de build de chaque sous-projet (ex: :app)
    // dans le répertoire de build racine.
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)

    // S'assure que la configuration de l':app est évaluée avant les autres
    // sous-projets qui pourraient en dépendre.
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
