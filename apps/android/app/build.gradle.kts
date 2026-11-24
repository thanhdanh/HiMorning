import java.io.FileInputStream
import java.net.URI
import java.security.MessageDigest
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

val handModelUrl = "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task"
val handModelSha256 = "fbc2a30080c3c557093b5ddfc334698132eb341044ccee322ccf8bcf3607cde1"
val handModelAssets = layout.buildDirectory.dir("generated/hand-model")

val prepareHandModel by tasks.registering {
    inputs.property("url", handModelUrl)
    inputs.property("sha256", handModelSha256)
    outputs.file(handModelAssets.map { it.file("hand_landmarker.task") })
    doLast {
        val output = handModelAssets.get().file("hand_landmarker.task").asFile
        val bytes = URI(handModelUrl).toURL().openConnection().apply {
            connectTimeout = 15_000
            readTimeout = 30_000
        }.getInputStream().use { it.readNBytes(8_000_001) }
        val sha256 = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
        check(sha256 == handModelSha256) { "Unexpected checksum for the MediaPipe hand model." }
        output.parentFile.mkdirs()
        output.writeBytes(bytes)
    }
}

val contentOrigin = providers.gradleProperty("himorningContentOrigin").orElse("").get()
if (contentOrigin.isNotEmpty()) {
    val origin = URI(contentOrigin)
    require(origin.scheme == "https" && origin.host?.endsWith(".workers.dev") == true &&
        origin.userInfo == null && origin.port == -1 && origin.rawQuery == null && origin.rawFragment == null &&
        (origin.rawPath == "" || origin.rawPath == "/")) { "Use the same HTTPS Workers origin as iOS." }
}

val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.isFile) {
        FileInputStream(keystorePropertiesFile).use(::load)
    }
}

android {
    namespace = "com.himorning.android"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.himorning.android"
        minSdk = 31
        targetSdk = 36
        versionCode = 3
        versionName = "1.0.1"
        buildConfigField("String", "CONTENT_ORIGIN", "\"$contentOrigin\"")
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    signingConfigs {
        create("release") {
            val storePath = keystoreProperties.getProperty("storeFile")
            if (!storePath.isNullOrBlank()) {
                storeFile = rootProject.file(storePath)
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        getByName("release") {
            if (keystorePropertiesFile.isFile) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    buildFeatures { compose = true; buildConfig = true }
    androidResources { noCompress += listOf("task", "m4a") }
    sourceSets.getByName("main").assets.srcDir(handModelAssets)
    bundle { language { enableSplit = false } }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    testOptions { unitTests.isReturnDefaultValues = true }
    sourceSets.getByName("test").resources.srcDir("src/main/assets")
}

kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }

tasks.named("preBuild").configure { dependsOn(prepareHandModel) }

dependencies {
    implementation(platform("androidx.compose:compose-bom:2025.09.01"))
    implementation("androidx.activity:activity-compose:1.11.0")
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended:1.7.8")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.4")
    implementation("androidx.camera:camera-camera2:1.5.0")
    implementation("androidx.camera:camera-lifecycle:1.5.0")
    implementation("androidx.camera:camera-view:1.5.0")
    implementation("com.google.mlkit:pose-detection:18.0.0-beta5")
    implementation("com.google.mediapipe:tasks-vision:0.10.33")
    implementation("com.google.mlkit:face-detection:16.1.7")
    debugImplementation("androidx.compose.ui:ui-tooling")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20250517")
}
