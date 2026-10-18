import java.util.Properties

val keyPropertiesFile = file(
    System.getenv("WATCHTOWER_KEY_PROPERTIES")?.takeIf { it.isNotBlank() }
        ?: "${System.getProperty("user.home")}/.config/watchtower/key.properties",
)
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) keyPropertiesFile.reader(Charsets.UTF_8).use { load(it) }
}
private val keyFields = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")

val uploadKeyReady = keyPropertiesFile.exists() &&
    keyFields.all { !keyProperties.getProperty(it).isNullOrBlank() }




val mapsKeysFile = file(
    System.getenv("WATCHTOWER_MAPS_KEYS")?.takeIf { it.isNotBlank() }
        ?: "${System.getProperty("user.home")}/.config/watchtower/maps_keys.properties",
)
val mapsApiKeyAndroid: String = Properties().apply {
    if (mapsKeysFile.exists()) mapsKeysFile.reader(Charsets.UTF_8).use { load(it) }
}.getProperty("MAPS_API_KEY_ANDROID")?.trim().orEmpty()


fun expandHome(path: String): String =
    if (path.startsWith("~/")) "${System.getProperty("user.home")}/${path.removePrefix("~/")}" else path

plugins {
    id("com.android.application")
    
    id("com.google.gms.google-services")
    
    
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "tw.watchtower.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        
        applicationId = "tw.watchtower.app"
        
        
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        
        
        
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        if (mapsApiKeyAndroid.isEmpty()) {
            throw GradleException(
                "Google 地圖金鑰 MAPS_API_KEY_ANDROID 不在 ${mapsKeysFile.path}，停止建置（見 build.gradle.kts 開頭說明）",
            )
        }
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKeyAndroid
    }

    signingConfigs {
        if (uploadKeyReady) {
            create("upload") {
                storeFile = file(expandHome(keyProperties.getProperty("storeFile")))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            
            signingConfig = signingConfigs.findByName("upload")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}


gradle.taskGraph.whenReady {
    
    val packagingRelease = Regex("^(assemble|bundle|package).*Release.*")
    val releaseTask = allTasks.any { it.project == project && packagingRelease.matches(it.name) }
    if (releaseTask && !uploadKeyReady) {
        throw GradleException(
            "上傳金鑰設定 ${keyPropertiesFile.path} 不存在或缺欄位（需 ${keyFields.joinToString("、")}），" +
                "停止 release 建置（見 android/app/build.gradle.kts 開頭說明）",
        )
    }
}
