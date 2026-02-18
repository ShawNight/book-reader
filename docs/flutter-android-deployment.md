# Flutter Android 部署指南

本文档记录了在 Linux 环境下将 Flutter 应用部署到 Android 设备时遇到的常见问题及解决方案。

## 环境要求

- Flutter SDK
- Android SDK
- Java JDK 17
- adb 工具

## 快速开始

```bash
# 1. 连接手机并确认
adb devices

# 2. 使用国内镜像运行（推荐）
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
flutter run
```

---

## 常见问题及解决方案

### 1. adb 命令未找到

**错误信息：**
```
adb: command not found
```

**解决方案：**
```bash
sudo apt install android-tools-adb
```

---

### 2. 手机未被识别

**检查步骤：**
```bash
# 检查 USB 连接
lsusb | grep -i android

# 检查 adb 设备
adb devices
```

**可能的原因：**
- 未开启 USB 调试（设置 → 开发者选项 → USB 调试）
- 未授权电脑调试（手机上点击"允许 USB 调试"）
- USB 连接模式错误（选择"文件传输"或 MTP 模式）

---

### 3. JAVA_HOME 未设置

**错误信息：**
```
ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.
```

**解决方案：**
```bash
# 安装 Java
sudo apt install openjdk-17-jdk

# 设置环境变量（添加到 ~/.bashrc）
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
```

---

### 4. Android SDK 许可证未接受

**错误信息：**
```
License for package Android SDK Build-Tools 30.0.3 not accepted.
License for package Android SDK Platform 34 not accepted.
```

**解决方案：**
```bash
# 创建许可证目录并添加许可证
sudo mkdir -p /usr/lib/android-sdk/licenses
echo -e "\n24333f8a63b6825ea9c5514f83c2829b004d1fee" | sudo tee /usr/lib/android-sdk/licenses/android-sdk-license
echo -e "\n84831b9409646a918e30573bab4c9c91346d8abd" | sudo tee -a /usr/lib/android-sdk/licenses/android-sdk-license
echo -e "\nd975f751698a77b662f1254ddbeed3901e976f5a" | sudo tee -a /usr/lib/android-sdk/licenses/android-sdk-license
```

---

### 5. SDK 目录权限不足

**错误信息：**
```
The SDK directory is not writable (/usr/lib/android-sdk)
```

**解决方案：**
```bash
sudo chmod -R 777 /usr/lib/android-sdk
```

---

### 6. 网络连接问题（无法下载 Flutter 依赖）

**错误信息：**
```
Could not GET 'https://storage.googleapis.com/download.flutter.io/...'
Connection reset
```

**解决方案（使用国内镜像）：**
```bash
# Flutter 官方镜像
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# 或使用清华镜像
export PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub
export FLUTTER_STORAGE_BASE_URL=https://mirrors.tuna.tsinghua.edu.cn/flutter
```

---

### 7. 缺少应用图标资源

**错误信息：**
```
error: resource mipmap/ic_launcher not found.
```

**解决方案：**

创建以下文件：

**android/app/src/main/res/drawable/ic_launcher_background.xml**
```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android">
    <solid android:color="#4A90D9"/>
</shape>
```

**android/app/src/main/res/drawable/ic_launcher_foreground.xml**
```xml
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <group android:scaleX="0.3" android:scaleY="0.3"
        android:translateX="37.8" android:translateY="37.8">
        <path android:fillColor="#FFFFFF"
            android:pathData="M54,27C38.5,27 27,41.5 27,54s11.5,27 27,27s27,-11.5 27,-27S69.5,27 54,27z"/>
    </group>
</vector>
```

**android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml**
```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
```

---

### 8. Kotlin 版本不兼容

**错误信息：**
```
Module was compiled with an incompatible version of Kotlin.
The binary version of its metadata is 1.9.0, expected version is 1.7.1.
```

**解决方案：**

修改 `android/settings.gradle`，更新 Kotlin 版本：
```groovy
plugins {
    // ... 其他插件
    id "org.jetbrains.kotlin.android" version "1.9.24" apply false
}
```

---

## 构建独立 APK

如果需要安装一个不需要连接电脑的独立版本：

```bash
# 构建 release 版本
flutter build apk --release

# APK 输出位置
# build/app/outputs/flutter-apk/app-release.apk
```

安装到设备：
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## 常用命令速查

| 命令 | 说明 |
|------|------|
| `flutter devices` | 列出可用设备 |
| `adb devices` | 列出已连接的 Android 设备 |
| `flutter run` | 运行应用（debug 模式） |
| `flutter run -d <device_id>` | 在指定设备上运行 |
| `flutter build apk --release` | 构建 release APK |
| `flutter clean` | 清理构建缓存 |

---

## 开发者模式说明

- **Debug 模式**：需要保持 USB 连接，支持热重载（按 `r` 键）
- **关闭开发者模式**：应用仍可正常运行，但无法进行代码更新
- **更新代码**：重新连接手机后运行 `flutter run` 即可更新应用
