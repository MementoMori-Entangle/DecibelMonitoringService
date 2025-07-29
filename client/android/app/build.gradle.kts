import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.protobuf") version "0.9.4"
    id("com.diffplug.spotless") version "6.25.0"
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.entangle.client"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    
    // META-INF/MANIFEST.MFの重複を解決
    packaging {
        resources {
            excludes.add("META-INF/versions/9/OSGI-INF/MANIFEST.MF")
            excludes.add("META-INF/MANIFEST.MF")
            excludes.add("META-INF/LICENSE")
            excludes.add("META-INF/*.SF")
            excludes.add("META-INF/*.DSA")
            excludes.add("META-INF/*.RSA")
        }
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.entangle.client"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    sourceSets {
        getByName("main") {
            java.srcDirs(
                "src/main/kotlin",
                "src/main/java",
                "build/app/generated/source/proto/main/java",
                "build/app/generated/source/proto/main/grpc"
            )
        }
        getByName("debug") {
            java.srcDirs(
                "src/main/kotlin",
                "src/main/java",
                "build/app/generated/source/proto/main/java",
                "build/app/generated/source/proto/main/grpc"
            )
        }
        getByName("release") {
            java.srcDirs(
                "src/main/kotlin",
                "src/main/java",
                "build/app/generated/source/proto/main/java",
                "build/app/generated/source/proto/main/grpc"
            )
        }
        getByName("profile") {
            java.srcDirs(
                "src/main/kotlin",
                "src/main/java",
                "build/app/generated/source/proto/main/java",
                "build/app/generated/source/proto/main/grpc"
            )
        }
    }

    signingConfigs {
        create("release") {
            storeFile = file(keystoreProperties["storeFile"] ?: "my-release-key.jks")
            storePassword = keystoreProperties["storePassword"] as String?
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?

			setProperty("archivesBaseName", "DecibelLogViewer-v${defaultConfig.versionName}")
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

spotless {
    kotlin {
        target("**/*.kt")
        ktlint("1.2.1")
    }
}

// gRPC/protobuf依存追加
dependencies {
    implementation("io.grpc:grpc-okhttp:1.63.0")
    implementation("io.grpc:grpc-protobuf:1.63.0")
    implementation("io.grpc:grpc-stub:1.63.0")
    implementation("javax.annotation:javax.annotation-api:1.3.2")
    implementation("org.bouncycastle:bcprov-jdk18on:1.78.1")
    implementation("org.bouncycastle:bcpkix-jdk18on:1.78.1")
}

protobuf {
    protoc {
        artifact = "com.google.protobuf:protoc:3.25.3"
    }
    plugins {
        create("grpc") {
            artifact = "io.grpc:protoc-gen-grpc-java:1.63.0"
        }
    }
    generateProtoTasks {
        all().forEach { task ->
            task.builtins {
                create("java")
            }
            task.plugins {
                create("grpc")
            }
        }
    }
}

tasks.register<Copy>("copyProto") {
    from("../../../proto/decibel_logger.proto")
    into("src/main/proto")
}

tasks.named("preBuild") {
    dependsOn("copyProto")
}

afterEvaluate {
    listOf("generateDebugProto", "generateReleaseProto", "generateProfileProto").forEach { taskName ->
        tasks.findByName(taskName)?.dependsOn("copyProto")
    }
}

tasks.named("spotlessKotlin") {
    dependsOn("copyProto")
}