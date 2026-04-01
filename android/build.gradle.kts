allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    pluginManager.withPlugin("com.android.library") {
        val androidExt = extensions.findByName("android") ?: return@withPlugin
        val namespaceGetter = androidExt.javaClass.methods.find { it.name == "getNamespace" }
        val namespaceSetter = androidExt.javaClass.methods.find {
            it.name == "setNamespace" && it.parameterTypes.size == 1
        }
        val currentNamespace = namespaceGetter?.invoke(androidExt) as? String

        if (currentNamespace.isNullOrBlank() && namespaceSetter != null) {
            val manifestFile = project.file("src/main/AndroidManifest.xml")
            val manifestNamespace = if (manifestFile.exists()) {
                val content = manifestFile.readText()
                Regex("package=\"([^\"]+)\"").find(content)?.groupValues?.getOrNull(1)
            } else {
                null
            }

            val fallbackNamespace = manifestNamespace
                ?: "com.legacy.${project.name.replace('-', '_')}"

            namespaceSetter.invoke(androidExt, fallbackNamespace)
        }

        pluginManager.withPlugin("org.jetbrains.kotlin.android") {
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                val jvmTarget = if (project.name == "package_info_plus") {
                    org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                } else {
                    org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
                }
                compilerOptions.jvmTarget.set(jvmTarget)
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

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
