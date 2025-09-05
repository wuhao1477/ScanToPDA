针对您的需求，我们将：

1. 在现有 workflow 中，新增基于应用名和版本号的 Release 命名。
2. 在发布时自动获取 Flutter 应用的`versionName`（或 `pubspec.yaml` 中的版本号）并注入到 Release 名称。
3. 提供一份开发文档，说明如何在 Flutter 前端使用 GitHub Releases 实现版本更新检测与下载安装，并优先考虑现成插件方案。

***

## 一、Workflow 配置优化

```yaml
name: Build & Release APK

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
        description: "🌐 目标网址 或 📱 应用包名"
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

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Checkout
        uses: actions/checkout@v4

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

      - name: Read version from pubspec.yaml
        id: read_version
        run: |
          version=$(grep '^version:' pubspec.yaml | awk '{print $2}')
          echo "version=$version" >> $GITHUB_OUTPUT

      - name: Build APK
        run: |
          # 使用彩蛋或标准流程构建
          ACTION_TYPE="${{ github.event.inputs.action_type }}"
          TARGET="${{ github.event.inputs.target }}"
          if [ "$ACTION_TYPE" = "none" ]; then
            flutter clean
            flutter pub get
            flutter build apk --release
          else
            ./build_with_easter_egg.sh "$ACTION_TYPE" "$TARGET"
          fi

      - name: Upload APK artifact
        uses: actions/upload-artifact@v4
        with:
          name: app-release-apk
          path: build/app/outputs/flutter-apk/app-release.apk

  release:
    needs: build
    if: startsWith(github.ref, 'refs/tags/v') 
        || (github.event_name == 'workflow_dispatch' && github.event.inputs.create_release == 'true')
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Download artifact
        uses: actions/download-artifact@v4
        with:
          name: app-release-apk
          path: artifacts

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: |
            ${{ startsWith(github.ref, 'refs/tags/') && github.ref_name || format('v{0}', steps.read_version.outputs.version) }}
          name: |
            ${{ format('{0} - {1}', github.event.repository.name, steps.read_version.outputs.version) }}
          files: artifacts/app-release.apk
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**说明：**
- `read_version` 步骤从 `pubspec.yaml` 中读取版本号，例如 `1.2.3+4`，并输出到 `${{ steps.read_version.outputs.version }}`。
- Release 的 `tag_name`：优先使用触发的 Tag；若手动触发且未使用 Tag，则自动生成 `v<version>`。
- Release 的 `name`：`<仓库名> - <版本号>`，满足“应用名字+版本号”命名要求。

***

## 二、Flutter 端版本更新服务方案

### 1. 插件选型

- **flutter_updater** 或 **ota_update**：可实现从 GitHub Releases 拉取最新 APK，并支持进度通知与安装（Android 需要额外权限）。
- **package_info_plus**：获取当前已安装版本号。
- **dio**：网络请求，若插件不内置可结合使用。

### 2. 开发文档示例

#### 2.1 安装依赖

```yaml
dependencies:
  package_info_plus: ^3.0.2
  dio: ^5.2.0
  ota_update: ^4.1.0
```

#### 2.2 获取当前版本

```dart
import 'package:package_info_plus/package_info_plus.dart';

Future<String> getCurrentVersion() async {
  final info = await PackageInfo.fromPlatform();
  return info.version; // e.g. "1.2.3"
}
```

#### 2.3 查询 GitHub Releases

```dart
import 'package:dio/dio.dart';

Future<Map<String, dynamic>> fetchLatestRelease(String owner, String repo) async {
  final dio = Dio();
  final url = 'https://api.github.com/repos/$owner/$repo/releases/latest';
  final resp = await dio.get(url);
  return resp.data; // 包含 tag_name, assets 等字段
}
```

#### 2.4 检查版本并下载

```dart
import 'package:ota_update/ota_update.dart';

Future<void> checkAndUpdate() async {
  final current = await getCurrentVersion();
  final release = await fetchLatestRelease('your-org', 'your-repo');
  final latestVersion = (release['tag_name'] as String).replaceFirst('v', '');
  if (latestVersion != current) {
    final asset = (release['assets'] as List).firstWhere(
      (e) => e['name'].endsWith('.apk'),
    );
    final downloadUrl = asset['browser_download_url'];
    OtaUpdate().execute(
      downloadUrl,
      destinationFilename: 'app-release.apk',
    ).listen(
      (event) {
        // 进度、状态回调
      },
    );
  }
}
```

#### 2.5 权限与安装

- 在 `AndroidManifest.xml` 中添加`<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>`。
- Android 8.0+ 需弹出用户授权外部来源安装。

***

以上即实现方案，涵盖 CI/CD 的 Release 自动命名与 Flutter 客户端的版本检测与安装服务。如有疑问，欢迎进一步交流！