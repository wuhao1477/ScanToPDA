你现有的 GitHub Actions 工作流已经具备了不错的基础，我们可以一起让它更强大，实现自动化发布到 Releases 并以应用名和版本号命名，同时为你的 Flutter 项目集成版本更新功能。

# 🚀 Flutter 项目自动化构建与版本更新服务方案

下面我将帮你优化 GitHub Actions 工作流，并设计一个完整的基于 GitHub Releases 的版本更新服务方案。

## 1. 优化后的 GitHub Actions 工作流

我基于你提供的 `build_apk_easter_egg.yml` 进行了优化，主要增加了**自动提取应用名和版本号**、**强化 Release 创建** 以及 **资源清理** 步骤：

```yaml
name: Build APK and Release

on:
  workflow_dispatch:
    inputs:
      action_type:
        description: "Easter egg action type (app|url)"
        required: true
        default: 'none'
        type: choice
        options:
          - none
          - app
          - url
      target:
        description: "🌐 目标网址 或 📱 应用包名 "
        required: false
        type: string
        default: ''
      create_release:
        description: "为此运行创建 GitHub Release"
        required: true
        default: 'false'
        type: choice
        options:
          - true
          - false
  push:
    tags:
      - 'v*.*.*'

jobs:
  build-and-release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Extract app name and version
        run: |
          # 提取应用名称（从pubspec.yaml）
          APP_NAME=$(grep 'name:' pubspec.yaml | head -1 | awk '{print $2}' | tr -d '\r')
          echo "APP_NAME=$APP_NAME" >> $GITHUB_ENV
          
          # 提取版本号（从pubspec.yaml）
          VERSION=$(grep 'version:' pubspec.yaml | head -1 | awk '{print $2}' | tr -d '\r')
          echo "VERSION=$VERSION" >> $GITHUB_ENV
          
          # 提取标签名（如果是标签触发）
          if [[ "${{ github.ref }}" == refs/tags/* ]]; then
            TAG_NAME=${GITHUB_REF#refs/tags/}
            echo "TAG_NAME=$TAG_NAME" >> $GITHUB_ENV
          else
            echo "TAG_NAME=manual-build-${{ github.run_number }}" >> $GITHUB_ENV
          fi
          
          echo "App: $APP_NAME, Version: $VERSION, Tag: $TAG_NAME"

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: zulu
          java-version: "17"

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: "3.35.2"
          cache: true

      - name: Show environment info
        run: |
          flutter --version
          echo "App Name: ${{ env.APP_NAME }}"
          echo "Version: ${{ env.VERSION }}"
          echo "Tag Name: ${{ env.TAG_NAME }}"

      - name: Make script executable
        run: chmod +x ./build_with_easter_egg.sh

      - name: Clean Flutter cache
        run: |
          flutter clean
          flutter pub cache clean

      - name: Build APK (non-interactive)
        shell: bash
        run: |
          set -euxo pipefail
          ACTION_TYPE="${{ github.event.inputs.action_type }}"
          TARGET="${{ github.event.inputs.target }}"

          # 如果操作类型为 'none'，则构建标准 APK（无彩蛋配置）
          if [ "$ACTION_TYPE" = "none" ]; then
            echo "📱 构建标准 APK（无彩蛋配置）..."
            flutter clean
            flutter pub get
            flutter build apk --release
            echo "✅ 标准 APK 构建完成！"
            echo "APK 位置: build/app/outputs/flutter-apk/app-release.apk"
          else
            # 使用彩蛋配置构建
            ./build_with_easter_egg.sh "$ACTION_TYPE" "$TARGET"
          fi

      - name: Rename APK with version
        run: |
          cd build/app/outputs/flutter-apk/
          NEW_NAME="${{ env.APP_NAME }}-${{ env.VERSION }}.apk"
          cp app-release.apk "$NEW_NAME"
          echo "NEW_APK_NAME=$NEW_NAME" >> $GITHUB_ENV
          echo "Renamed APK to: $NEW_NAME"

      - name: Upload APK artifact
        uses: actions/upload-artifact@v4
        with:
          name: ${{ env.NEW_APK_NAME }}
          path: build/app/outputs/flutter-apk/${{ env.NEW_APK_NAME }}

      - name: Create GitHub Release
        if: startsWith(github.ref, 'refs/tags/v') || github.event.inputs.create_release == 'true'
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ env.TAG_NAME }}
          name: ${{ env.APP_NAME }} ${{ env.VERSION }}
          body: |
            ## ${{ env.APP_NAME }} 版本 ${{ env.VERSION }}
            
            ### 更新内容
            本次更新包含以下改进：
            - 功能优化和错误修复
            - 性能提升
            
            ### SHA256 校验和
            $${{ hashFiles('build/app/outputs/flutter-apk/' + env.NEW_APK_NAME) }}
            
            ### 安装说明
            1. 下载APK文件
            2. 在设备上安装
            3. 享受新版本!
          files: build/app/outputs/flutter-apk/${{ env.NEW_APK_NAME }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Clean up workspace
        run: |
          rm -f build/app/outputs/flutter-apk/*.apk
          echo "Workspace cleaned up"
```

## 2. Flutter 端版本更新服务集成

在你的 Flutter 项目中，可以使用 `flutter_xupdate` 插件来实现基于 GitHub Releases 的版本更新功能。

### 2.1 添加依赖
在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  flutter_xupdate: ^2.0.0
  package_info_plus: ^5.0.0
```

### 2.2 初始化更新服务
创建 `lib/services/update_service.dart`：

```dart
import 'package:flutter_xupdate/flutter_xupdate.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static final String _releaseUrl =
      "https://api.github.com/repos/<你的用户名>/<你的仓库>/releases/latest";
  
  // 初始化版本更新
  static void initXUpdate() {
    FlutterXUpdate.init(
      debug: true,
      isWifiOnly: false,
      isAutoMode: false,
      supportSilentInstall: false,
    ).then((value) {
      print("初始化成功: $value");
    }).catchError((error) {
      print("初始化失败: $error");
    });
    
    FlutterXUpdate.setErrorHandler(
      onUpdateError: (error) async {
        print("更新错误: $error");
      },
    );
  }
  
  // 检查更新
  static Future<void> checkUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      
      print("当前版本: $currentVersion");
      
      await FlutterXUpdate.checkUpdate(
        url: _releaseUrl,
        isPost: false,
        isPostJson: false,
        showLoading: true,
      );
    } catch (e) {
      print("检查更新失败: $e");
    }
  }
  
  // 解析GitHub API的响应
  static Map<String, dynamic> parseGitHubResponse(Map<String, dynamic> json) {
    try {
      // GitHub API返回的数据结构
      String versionName = json['tag_name'] ?? '1.0.0';
      String updateContent = json['body'] ?? '版本更新';
      String downloadUrl = "";
      int updateStatus = 1;
      
      // 查找apk资源
      if (json['assets'] != null && json['assets'].isNotEmpty) {
        for (var asset in json['assets']) {
          if (asset['name'] != null && asset['name'].endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'] ?? '';
            break;
          }
        }
      }
      
      // 获取当前版本信息
      PackageInfo.fromPlatform().then((packageInfo) {
        String currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
        // 如果最新版本与当前版本相同，则不更新
        if (versionName == currentVersion) {
          updateStatus = 0;
        }
      });
      
      return {
        "Code": 0,
        "Msg": "成功",
        "UpdateStatus": updateStatus,
        "VersionCode": versionName.replaceAll(RegExp(r'[^0-9]'), ''),
        "VersionName": versionName,
        "ModifyContent": updateContent,
        "DownloadUrl": downloadUrl,
        "ApkSize": 1024,
        "ApkMd5": ""
      };
    } catch (e) {
      return {
        "Code": -1,
        "Msg": "解析失败: $e",
        "UpdateStatus": 0,
      };
    }
  }
}
```

### 2.3 在主应用中集成
在 `main.dart` 中集成版本更新：

```dart
import 'package:flutter/material.dart';
import 'services/update_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化版本更新
  UpdateService.initXUpdate();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '你的应用名称',
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // 可选：启动时检查更新
    // Future.delayed(Duration(seconds: 3), () => UpdateService.checkUpdate());
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('你的应用名称'),
        actions: [
          IconButton(
            icon: Icon(Icons.update),
            onPressed: () => UpdateService.checkUpdate(),
            tooltip: '检查更新',
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('欢迎使用我们的应用'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => UpdateService.checkUpdate(),
              child: Text('检查更新'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 2.4 Android配置
在 `android/app/src/main/res/values/styles.xml` 中确保使用 AppCompat 主题：

```xml
<resources>
    <style name="LaunchTheme" parent="Theme.AppCompat.Light.NoActionBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
</resources>
```

## 3. 版本管理规范

为确保自动化流程顺利工作，建议遵循以下规范：

### 3.1 语义化版本控制
使用 `主版本号.次版本号.修订号` 格式（如 `1.2.3`）：
- **主版本号**：不兼容的 API 修改
- **次版本号**：向后兼容的功能性新增
- **修订号**：向后兼容的问题修正

### 3.2 标签命名规范
使用 `v版本号` 格式（如 `v1.2.3`）创建 Git 标签，这将自动触发 Release 创建流程。

### 3.3 提交信息规范
采用约定式提交，有助于未来生成变更日志：
- `feat:` 新功能
- `fix:` 问题修复
- `docs:` 文档更新
- `style:` 代码格式调整
- `refactor:` 代码重构
- `perf:` 性能优化
- `test:` 测试相关
- `chore:` 构建过程或辅助工具的变动

## 4. API接口说明

`flutter_xupdate` 期望的JSON响应格式如下：

```json
{
  "Code": 0,
  "Msg": "成功",
  "UpdateStatus": 1,
  "VersionCode": "100",
  "VersionName": "v1.0.0",
  "ModifyContent": "1. 修复已知问题\n2. 优化性能",
  "DownloadUrl": "https://github.com/username/repo/releases/download/v1.0.0/appname-v1.0.0.apk",
  "ApkSize": 20480,
  "ApkMd5": "a1b2c3d4e5f6g7h8i9j0"
}
```

## 5. 高级配置选项

### 5.1 自定义更新对话框
你可以自定义更新对话框的样式和行为：

```dart
FlutterXUpdate.checkUpdate(
  url: _releaseUrl,
  widthRatio: 0.7,
  themeColor: Colors.blue,
  topImage: "assets/update_top.png",
  enableRetry: true,
);
```

### 5.2 后台更新
支持后台下载和安装：

```dart
FlutterXUpdate.checkUpdate(
  url: _releaseUrl,
  supportBackgroundUpdate: true,
);
```

## 6. 注意事项

1.  **GitHub Token权限**：确保 GitHub Actions 工作流有足够的权限创建 Releases（在仓库 Settings > Actions > General 中配置）
2.  **网络权限**：Android 应用需要互联网权限，在 `android/app/src/main/AndroidManifest.xml` 中添加：
    ```xml
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    ```
3.  **文件存储权限**：如果支持后台更新，需要添加存储权限
4.  **iOS限制**：`flutter_xupdate` 目前仅支持 Android

这套方案实现了你的 Flutter 项目基于 GitHub Releases 的自动化构建和版本更新服务，每次打标签推送时会自动构建 APK 并发布到 Releases，并以"应用名-版本号"格式命名。用户可以在应用中直接检查并安装更新。
