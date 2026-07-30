allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Force every plugin subproject onto a modern compileSdk and ONE
// consistent JVM (17) for BOTH Java and Kotlin. Some plugins hard-code
// jvmTarget 1.8 for Kotlin (flutter_timezone) or Java (flutter_foreground_task)
// in their own build files; these task-level rules run after and win.
subprojects {
    afterEvaluate {
        // Kotlin toolchain for well-behaved plugins.
        extensions.findByType(org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java)
            ?.jvmToolchain(17)

        // Force every Kotlin compile task to 17 (overrides plugin hard-codes).
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }

        // ...and every Java compile task to 17 (the mirror image).
        tasks.withType(JavaCompile::class.java).configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }

        // Modern compileSdk on every plugin, works on new and old AGP DSLs.
        extensions.findByName("android")?.withGroovyBuilder {
            try {
                setProperty("compileSdk", 36)
            } catch (_: Exception) {
                try { "compileSdkVersion"(36) } catch (_: Exception) {}
            }
        }
    }
}

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}