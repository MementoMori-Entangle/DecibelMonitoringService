plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.protobuf") version "0.9.4"
    id("com.diffplug.spotless") version "6.25.0"
}

android {
    namespace = "com.entangle.client"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
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