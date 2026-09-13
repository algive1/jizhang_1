import com.android.build.api.dsl.LibraryExtension

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

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Older payment SDK plugins omit the namespace and compile SDK required by
// the current AGP. Keep the compatibility fix in the app build rather than
// editing Pub cache, and register it before evaluationDependsOn can run.
subprojects {
    plugins.withId("com.android.library") {
        if (project.name == "alipay_kit_android" || project.name == "wechat_kit") {
            extensions.configure<LibraryExtension> {
                if (project.name == "alipay_kit_android" && namespace == null) {
                    namespace = "io.github.v7lin.alipay_kit_android"
                }
            }
        }
    }
    if (project.name == "alipay_kit_android" || project.name == "wechat_kit") {
        afterEvaluate {
            extensions.configure<LibraryExtension> {
                if ((compileSdk ?: 0) < 34) compileSdk = 36
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
