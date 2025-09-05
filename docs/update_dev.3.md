

# **自动化 Flutter 发布与 GitHub 版本更新框架**

---

### **引言：建立专业的发布与更新流程**

从手动构建和分发应用过渡到全自动、专业级的发布管理体系，是提升软件开发成熟度的关键一步。本报告旨在提供一个全面的框架，将现有的构建流程升级为一个集成的、自动化的发布与更新系统。该框架不仅能显著提高发布流程的可靠性、减少人为错误，更能优化最终用户的更新体验。

此框架的核心由三大支柱构成：

* **动态 CI/CD 管道：** 一个能够智能读取并适应应用程序元数据（如版本号和应用名称）的持续集成与部署工作流。  
* **GitHub Releases 作为轻量级后端：** 利用现有的 GitHub 基础设施作为版本更新的分发服务器，无需部署和维护专门的后端服务。  
* **客户端更新服务：** 在 Flutter 应用内部实现一个无缝、安全且用户友好的更新机制。

本报告将分为两个主要部分。第一部分将详细阐述如何改造现有的 GitHub Actions 工作流，以实现动态化的构建与发布。第二部分将提供一份详尽的开发文档，指导如何在 Flutter 应用中构建一个由 GitHub Releases 驱动的应用内更新服务。这两部分将共同构成一个紧密协作、端到端的解决方案。

---

### **第一部分：构建动态化的 CI/CD 发布管道**

本部分的核心目标是将静态的、手动的构建过程，转变为一个智能的、由元数据驱动的自动化发布管道。

#### **1.1 在 CI 环境中提取应用程序元数据**

为了实现自动化，首要任务是在 GitHub Actions 的运行环境中，以编程方式可靠地读取 pubspec.yaml 文件中的 name 和 version 字段。

pubspec.yaml 文件是 Flutter 项目的权威信息源，它定义了项目的名称、版本、依赖等核心元数据 1。在自动化流程中，必须确保能准确无误地解析此文件。

虽然可以使用 grep、sed 或 awk 等标准的 shell 工具来尝试解析 YAML 文件，但这种方法极其脆弱 2。这些工具基于行和正则表达式进行匹配，对文件的格式（如缩进、注释、或字符串是否使用引号）非常敏感。任何微小的、对 YAML 语法有效的格式调整，都可能导致解析脚本失效，从而破坏整个 CI/CD 管道的稳定性。

这种脆弱性凸显了在 DevOps 实践中一个成熟的理念：应始终优先选择专为特定任务设计的健壮工具，而非依赖复杂的自定义脚本。对于解析 YAML，yq 是业界公认的标准工具 2。与基于文本匹配的脚本不同，

yq 能够将 YAML 文件完整地解析为一个抽象语法树，然后对这个结构化的数据进行查询。这种方法使其完全不受文件格式变化的影响，保证了元数据提取的可靠性和准确性。

以下是在 GitHub Actions 工作流中集成 yq 以提取应用名称和版本，并将其设置为后续步骤可用的环境变量和输出的具体实现：

YAML

\- name: Install yq  
  run: |  
    sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq\_linux\_amd64 \-O /usr/bin/yq  
    sudo chmod \+x /usr/bin/yq

\- name: Read app name and version from pubspec.yaml  
  id: pubspec  
  run: |  
    \# 从 pubspec.yaml 中读取 name 和 version  
    \# yq 的 \-r 参数表示输出原始字符串，不带引号  
    APP\_NAME=$(yq \-r.name pubspec.yaml)  
    APP\_VERSION=$(yq \-r.version pubspec.yaml)  
      
    \# 将变量写入 GITHUB\_ENV，使其在当前 job 的后续步骤中可用  
    echo "APP\_NAME=$APP\_NAME" \>\> $GITHUB\_ENV  
    echo "APP\_VERSION=$APP\_VERSION" \>\> $GITHUB\_ENV  
      
    \# 构造最终的 APK 文件名，并将其设置为 job 的输出  
    \# 这样其他 job 也可以引用这个文件名  
    echo "apk\_filename=${APP\_NAME}-v${APP\_VERSION}.apk" \>\> $GITHUB\_OUTPUT

#### **1.2 实现动态资产命名与发布自动化**

在成功提取元数据后，下一步是修改 build\_apk\_easter\_egg.yml 工作流，利用这些动态数据来重命名构建产物（APK），并将其上传到一个以版本号命名的 GitHub Release 中。

第一步：动态重命名构建产物  
在 Build APK 步骤成功执行后，需要增加一个新步骤，将默认生成的 app-release.apk 文件重命名为包含版本号的格式。这是一个关键的中间操作，可以使用标准的 mv 命令完成 8。

YAML

\- name: Rename APK with version  
  \# 使用上一步 'pubspec' 的输出 'apk\_filename'  
  run: mv build/app/outputs/flutter-apk/app-release.apk ${{ steps.pubspec.outputs.apk\_filename }}

第二步：修改 upload-artifact 操作  
接下来，更新 actions/upload-artifact 步骤，使其上传经过重命名的文件。这确保了在不同作业（jobs）之间传递的构建产物具有正确的、版本化的名称 9。

YAML

\- name: Upload APK artifact  
  uses: actions/upload-artifact@v4  
  with:  
    \# artifact 的名称可以保持通用  
    name: versioned-apk  
    \# 上传的路径现在是动态生成的文件名  
    path: ${{ steps.pubspec.outputs.apk\_filename }}

第三步：重构 release 作业  
release 作业是整个流程的终点，负责将构建产物发布给最终用户。需要对其进行彻底的改造。  
首先，必须理解 actions/upload-artifact 和 softprops/action-gh-release 之间的协同关系。它们并非相互替代，而是在一个健壮的发布工作流中扮演着不同但互补的角色。build-apk 作业和 release 作业运行在两个独立的虚拟机环境中。因此，需要一个机制将 APK 文件从构建环境安全地传输到发布环境。这正是 actions/upload-artifact 和 actions/download-artifact 的核心功能——它们充当了作业之间内部数据传输的桥梁 10。而

softprops/action-gh-release 则负责将从上一个作业接收到的文件，发布到永久的、面向公众的 GitHub Releases 存储中 12。将构建与发布解耦为独立的作业，是现代 CI/CD 的最佳实践，它极大地提高了工作流的模块化和可维护性。

对 softprops/action-gh-release 操作的配置进行如下优化：

* **tag\_name 和 name：** 当工作流由 Git 标签触发时，应直接使用 github.ref\_name 来设置发布的标签和标题，确保 Release 与代码仓库中的 Git 标签完全对应 14。  
* **files：** 这是最关键的改动。此参数需要指向从 build-apk 作业下载下来的、具有动态名称的 APK 文件。这要求在 release 作业中先下载 artifact，然后引用其路径 12。

#### **1.3 最终修订的 build\_apk\_easter\_egg.yml 工作流**

以下是经过全面优化和注释的完整工作流文件。它整合了上述所有改进，形成了一个动态、健壮且自动化的发布流程。

YAML

name: Build and Release Flutter APK

on:  
  \# 允许通过 Git 推送 v\*.\*.\* 格式的标签来触发  
  push:  
    tags:  
      \- 'v\*.\*.\*'  
  \# 保持手动触发的能力，用于测试或特殊构建  
  workflow\_dispatch:  
    inputs:  
      action\_type:  
        description: "Easter egg action type (app|url)"  
        required: true  
        default: 'none'  
        type: choice  
        options:  
          \- none  
          \- app  
          \- url  
      target:  
        description: "🌐 目标网址 或 📱 应用包名"  
        required: false  
        type: string  
        default: ''  
      create\_release:  
        description: "为此运行创建 GitHub Release (仅手动触发时有效)"  
        required: true  
        default: 'false'  
        type: choice  
        options:  
          \- 'true'  
          \- 'false'

jobs:  
  build-apk:  
    runs-on: ubuntu-latest  
    permissions:  
      contents: read \# 构建过程只需要读取权限  
    outputs:  
      \# 定义一个输出，用于将动态生成的文件名传递给 release job  
      apk\_filename: ${{ steps.pubspec.outputs.apk\_filename }}  
      app\_version: ${{ env.APP\_VERSION }}

    steps:  
      \- name: Checkout repository  
        uses: actions/checkout@v4

      \- name: Setup Java  
        uses: actions/setup-java@v4  
        with:  
          distribution: 'zulu'  
          java-version: '17'

      \- name: Setup Flutter  
        uses: subosito/flutter-action@v2  
        with:  
          channel: 'stable'  
          cache: true

      \- name: Install yq for YAML parsing  
        run: |  
          sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq\_linux\_amd64 \-O /usr/bin/yq  
          sudo chmod \+x /usr/bin/yq

      \- name: Read app name and version from pubspec.yaml  
        id: pubspec  
        run: |  
          APP\_NAME=$(yq \-r.name pubspec.yaml)  
          APP\_VERSION=$(yq \-r.version pubspec.yaml)  
          echo "APP\_NAME=$APP\_NAME" \>\> $GITHUB\_ENV  
          echo "APP\_VERSION=$APP\_VERSION" \>\> $GITHUB\_ENV  
          echo "apk\_filename=${APP\_NAME}-v${APP\_VERSION}.apk" \>\> $GITHUB\_OUTPUT

      \- name: Install dependencies  
        run: flutter pub get

      \- name: Build APK  
        \# 此处省略了原有的彩蛋构建逻辑，可根据需要加回  
        run: flutter build apk \--release

      \- name: Rename APK with app name and version  
        run: mv build/app/outputs/flutter-apk/app-release.apk ${{ steps.pubspec.outputs.apk\_filename }}

      \- name: Upload APK as artifact  
        uses: actions/upload-artifact@v4  
        with:  
          name: versioned-apk  
          path: ${{ steps.pubspec.outputs.apk\_filename }}

  release:  
    \# 依赖 build-apk job 完成  
    needs: build-apk  
    runs-on: ubuntu-latest  
    \# 仅在推送标签或手动调度并选择创建 release 时运行  
    if: startsWith(github.ref, 'refs/tags/v') |

| (github.event\_name \== 'workflow\_dispatch' && github.event.inputs.create\_release \== 'true')  
    permissions:  
      \# 发布需要写入内容的权限  
      contents: write  
      
    steps:  
      \- name: Download APK artifact  
        uses: actions/download-artifact@v4  
        with:  
          name: versioned-apk  
          \# 下载到当前工作目录  
          path:.

      \- name: Create GitHub Release  
        uses: softprops/action-gh-release@v2  
        with:  
          \# 如果是标签触发，使用标签名；否则，为手动构建生成一个唯一的名称  
          tag\_name: ${{ github.ref\_name |

| format('manual-build-{0}', github.run\_number) }}  
          name: Release ${{ github.ref\_name |

| format('Manual Build {0}', github.run\_number) }}  
          \# 将下载的、已重命名的 APK 文件作为发布资产  
          files: ${{ needs.build-apk.outputs.apk\_filename }}  
          \# 如果不是由标签触发的，则标记为预发布版本  
          prerelease: ${{\!startsWith(github.ref, 'refs/tags/') }}

---

### **第二部分：设计 Flutter 应用内更新服务**

本部分将提供一份完整的开发者指南，详细介绍如何在 Flutter 应用内部构建一个可靠、用户体验良好的版本更新服务。

#### **2.1 自托管更新机制的原理**

此更新服务的核心架构不依赖任何传统的应用商店，而是将 GitHub Releases 作为一个轻量级、无需成本的后端服务。

更新生命周期  
整个更新流程遵循一个清晰的逻辑闭环：

1. **检查 (Check):** 应用启动时，异步向 GitHub API 发起请求，查询最新版本信息。  
2. **比较 (Compare):** 将获取到的最新版本号与应用自身安装的版本号进行比较。  
3. **通知 (Notify):** 如果发现新版本，通过一个非阻塞式的、友好的用户界面（如对话框或提示条）通知用户。  
4. **下载 (Download):** 用户同意更新后，在后台下载新的 APK 文件，并实时显示下载进度。  
5. **安装 (Install):** 下载完成后，引导用户触发系统的安装流程。

GitHub API 端点  
此服务将使用 GitHub REST API 提供的标准端点来获取最新发布信息：  
GET /repos/{owner}/{repo}/releases/latest 16  
该端点返回一个 JSON 对象，其中包含两个对我们至关重要的字段：

* tag\_name: 字符串类型，代表最新发布版的版本号（例如 v1.2.1）。  
* assets: 一个数组，包含了该发布版的所有资产。我们需要从中找到 APK 文件，并获取其 browser\_download\_url 字段，即文件的公开下载链接。

#### **2.2 Flutter 更新插件生态系统分析**

在选择实现此功能的 Flutter 插件时，一个根本性的架构决策起到了决定性作用：**使用 GitHub Releases 作为更新源，立即排除了所有依赖应用商店的插件**。

市面上的更新插件主要分为两大类：

1. **应用商店检查型：** 如 upgrader 18 和  
   app\_version\_update 21，它们通过查询 Google Play 或 Apple App Store 的 API 来获取应用的最新版本信息。这种机制与我们基于 GitHub 的自托管模型完全不兼容。  
2. **直接下载安装型 (OTA \- Over-The-Air)：** 如 ota\_update 22，这类插件的核心功能是从一个给定的 URL 下载 APK 文件并触发系统安装。这正是我们需要的模式。

因此，问题不在于“哪个更新插件最好”，而在于“哪个插件或插件组合最适合我们选择的 OTA 架构”。为了获得最大的灵活性和对更新流程的完全控制，推荐采用一组功能专一、高度协作的“辅助”插件来构建更新服务，而不是依赖单一的、大而全的插件。

**表 1: Flutter 应用内更新相关插件对比分析**

| 插件名称 | 核心功能 | GitHub Releases 兼容性 | 角色定位 |
| :---- | :---- | :---- | :---- |
| upgrader | 从应用商店检查版本 | 不兼容 | \- |
| in\_app\_update | 封装原生 Android 应用内更新 API | 不兼容（依赖 Play Store） | \- |
| ota\_update | 从 URL 下载并安装 APK | **高度兼容** | 备选方案，但手动实现更灵活 |
| http | 发起 HTTP 请求 | **高度兼容** | **核心组件** (用于API请求) |
| package\_info\_plus | 获取当前应用的版本信息 | **高度兼容** | **核心组件** (用于版本比较) |
| pub\_semver | 语义化版本号比较 | **高度兼容** | **核心组件** (用于版本比较) |
| dio | 功能强大的 HTTP 客户端 | **高度兼容** | **核心组件** (用于带进度的文件下载) |
| path\_provider | 获取设备文件系统路径 | **高度兼容** | **核心组件** (用于存储APK) |
| open\_filex | 调用原生能力打开文件 | **高度兼容** | **核心组件** (用于触发APK安装) |

基于以上分析，我们将采用 http, package\_info\_plus, pub\_semver, dio, path\_provider, 和 open\_filex 的组合拳，来构建一个功能完备且高度可定制的更新服务。

#### **2.3 更新服务的参考实现**

本节提供构建 UpdateService 的详细步骤和生产级质量的代码。

2.3.1 依赖配置  
首先，在 pubspec.yaml 文件中添加必要的依赖：

YAML

dependencies:  
  flutter:  
    sdk: flutter  
  http: ^1.2.1  
  package\_info\_plus: ^8.0.0  
  pub\_semver: ^2.1.4  
  dio: ^5.4.3+1  
  path\_provider: ^2.1.3  
  open\_filex: ^4.4.0

2.3.2 UpdateService 类结构  
创建一个单例 UpdateService 类来封装所有更新逻辑，便于在应用各处调用。

Dart

import 'dart:convert';  
import 'dart:io';

import 'package:dio/dio.dart';  
import 'package:http/http.dart' as http;  
import 'package:open\_filex/open\_filex.dart';  
import 'package:package\_info\_plus/package\_info\_plus.dart';  
import 'package:path\_provider/path\_provider.dart';  
import 'package:pub\_semver/pub\_semver.dart';

class UpdateService {  
  // 替换为你的 GitHub 用户名和仓库名  
  static const String \_githubOwner \= 'YOUR\_GITHUB\_USERNAME';  
  static const String \_githubRepo \= 'YOUR\_GITHUB\_REPO';  
  static const String \_apiUrl \= 'https://api.github.com/repos/$\_githubOwner/$\_githubRepo/releases/latest';

  // 私有构造函数  
  UpdateService.\_();

  // 单例实例  
  static final UpdateService instance \= UpdateService.\_();

  //... 后续方法将在此实现  
}

2.3.3 获取最新发布元数据  
此方法负责调用 GitHub API，解析响应，并返回包含版本号和下载链接的数据模型。

Dart

class ReleaseInfo {  
  final String version;  
  final String downloadUrl;  
  final String releaseNotes;

  ReleaseInfo({required this.version, required this.downloadUrl, required this.releaseNotes});  
}

Future\<ReleaseInfo?\> getLatestReleaseInfo() async {  
  try {  
    final response \= await http.get(Uri.parse(\_apiUrl));  
    if (response.statusCode \== 200) {  
      final json \= jsonDecode(response.body);  
      final tagName \= json\['tag\_name'\] as String;  
      final releaseNotes \= json\['body'\] as String;  
        
      final assets \= json\['assets'\] as List;  
      if (assets.isNotEmpty) {  
        // 假设第一个 asset 就是我们的 APK  
        final apkAsset \= assets.firstWhere(  
          (asset) \=\> (asset\['name'\] as String).endsWith('.apk'),  
          orElse: () \=\> null,  
        );

        if (apkAsset\!= null) {  
          final downloadUrl \= apkAsset\['browser\_download\_url'\] as String;  
          // 移除版本号前的 'v' 前缀，以便后续比较  
          final cleanVersion \= tagName.startsWith('v')? tagName.substring(1) : tagName;  
          return ReleaseInfo(version: cleanVersion, downloadUrl: downloadUrl, releaseNotes: releaseNotes);  
        }  
      }  
    }  
  } catch (e) {  
    print('Failed to get latest release info: $e');  
  }  
  return null;  
}

2.3.4 实现稳健的版本比较  
简单的字符串比较版本号（如 "10.0.0" \< "2.0.0"）是不可靠的，因为它遵循字典序而非数值逻辑。为了正确处理复杂的版本号（如 1.2.0+3、2.0.0-beta.1），必须使用专门的语义化版本控制库。pub\_semver 包正是为此而生，它能够将版本字符串解析为结构化对象，并根据 SemVer 2.0.0 规范进行精确比较 24。这是确保更新逻辑在所有情况下都能正确运行的关键。

Dart

Future\<bool\> isUpdateAvailable(String latestVersionStr) async {  
  final packageInfo \= await PackageInfo.fromPlatform();  
  final currentVersionStr \= packageInfo.version;

  try {  
    final currentVersion \= Version.parse(currentVersionStr);  
    final latestVersion \= Version.parse(latestVersionStr);  
    return latestVersion \> currentVersion;  
  } catch (e) {  
    print('Error parsing versions: $e');  
    return false;  
  }  
}

2.3.5 用户体验：通知与进度  
当检测到新版本时，应以清晰的方式通知用户。在下载过程中，提供实时的进度反馈至关重要。dio 包的 download 方法提供了 onReceiveProgress 回调，非常适合实现此功能 25。

Dart

// 在你的 UI 代码中 (例如，一个 StatefulWidget)  
void checkForUpdate() async {  
  final releaseInfo \= await UpdateService.instance.getLatestReleaseInfo();  
  if (releaseInfo\!= null) {  
    final updateAvailable \= await UpdateService.instance.isUpdateAvailable(releaseInfo.version);  
    if (updateAvailable && mounted) {  
      showUpdateDialog(context, releaseInfo);  
    }  
  }  
}

void showUpdateDialog(BuildContext context, ReleaseInfo releaseInfo) {  
  showDialog(  
    context: context,  
    builder: (context) \=\> AlertDialog(  
      title: Text('发现新版本: ${releaseInfo.version}'),  
      content: SingleChildScrollView(child: Text(releaseInfo.releaseNotes)),  
      actions:,  
    ),  
  );  
}

//... 实现 startDownload 方法，其中包含进度条UI

2.3.6 管理 APK 下载与安装  
下载的 APK 文件需要一个临时存储位置。path\_provider 可以安全地获取应用的文档目录。下载完成后，open\_filex 负责调用 Android 系统的安装程序来处理 APK 文件 27。

Dart

Future\<void\> downloadAndInstallApk(String url, Function(int, int) onProgress) async {  
  try {  
    // 获取临时目录  
    final tempDir \= await getTemporaryDirectory();  
    final filePath \= '${tempDir.path}/app-update.apk';

    // 使用 dio 下载文件  
    final dio \= Dio();  
    await dio.download(  
      url,  
      filePath,  
      onReceiveProgress: onProgress,  
    );

    // 下载完成后，打开文件以触发安装  
    final result \= await OpenFilex.open(filePath);  
    if (result.type\!= ResultType.done) {  
      print('Failed to open APK file: ${result.message}');  
    }  
  } catch (e) {  
    print('Download or install failed: $e');  
  }  
}

关于 Android 权限的重要说明：  
在 Android 系统上，从应用外部安装 APK 需要用户手动授予“安装未知应用”的权限。应用本身无法以编程方式开启此权限。当用户首次尝试通过此流程更新时，Android 操作系统会自动将用户引导至系统设置页面以授予该权限。这是 Android 的一项核心安全机制，旨在保护用户免受恶意应用的侵害。Google Play 对 REQUEST\_INSTALL\_PACKAGES 权限有严格的政策限制，进一步强调了这是一个高度敏感的操作，必须由用户明确授权 28。

---

### **结论：整合工作流与生产环境最佳实践**

本报告详细阐述了一个完整的自动化发布与更新框架。整个流程无缝衔接：开发者向仓库推送一个 v1.2.1 格式的 Git 标签，CI/CD 管道自动被触发。管道会读取版本号，构建应用，将产物命名为 my-app-v1.2.1.apk，并将其发布到一个新的 GitHub Release。当终端用户下一次打开应用时，UpdateService 会自动检测到 v1.2.1 版本的发布，发现它比当前安装的版本更新，并友好地提示用户进行升级。

为了将此框架安全地部署到生产环境，以下建议至关重要：

* 安全加固：使用校验和防止中间人攻击 (MITM)  
  一个完全依赖下载链接的更新系统存在被中间人攻击的风险——攻击者可能在不安全的网络环境下篡改下载链接或文件内容。为了确保用户下载的 APK 与 CI 环境中构建的完全一致，必须引入文件完整性校验。  
  1. **在 CI/CD 管道中生成校验和：** 在构建并重命名 APK 后，增加一个步骤来计算其 SHA256 校验和（例如，使用 sha256sum my-app-v1.2.1.apk \> checksum.txt）。  
  2. **将校验和发布到 Release：** 在 softprops/action-gh-release 步骤中，将生成的 checksum.txt 文件也作为资产上传，或者直接将校验和字符串写入 Release 的描述（body）中。  
  3. **在 Flutter 应用中进行验证：** 应用在下载完 APK 后，必须在本地计算该文件的 SHA256 校验和。然后，将计算出的值与从 GitHub Release 描述或 checksum.txt 文件中获取的官方校验和进行比对。只有在两个值完全匹配的情况下，才调用 open\_filex 触发安装。ota\_update 插件的文档也明确提到了支持校验和验证，这证实了其作为行业最佳实践的重要性 23。这个闭环校验过程建立了一条从构建服务器到用户设备的信任链，从根本上保证了更新的安全性。  
* 处理预发布版本 (Pre-releases):  
  对于测试版（如 v2.0.0-beta.1），可以在 softprops/action-gh-release 中设置 prerelease: true。客户端的 UpdateService 也应相应调整，可以根据应用设置决定是否向普通用户推送预发布版本。  
* 优雅的错误处理:  
  应用内的更新服务需要能够妥善处理各种异常情况，如网络中断、下载失败、校验和不匹配或 GitHub API 不可用等，并向用户提供清晰的反馈，避免应用崩溃或用户困惑。  
* 最终的工作流触发策略:  
  虽然 workflow\_dispatch 对于调试和手动构建非常有用，但所有正式的生产发布都应严格通过推送 Git 标签 (on: push: tags: \- 'v\*.\*.\*') 来触发。这确保了每一个公开发布的版本都与代码库中一个明确的、不可变的历史节点相对应，实现了发布的可追溯性和可复现性。

#### **引用的著作**

1. Flutter pubspec options, 访问时间为 九月 5, 2025， [https://docs.flutter.dev/tools/pubspec](https://docs.flutter.dev/tools/pubspec)  
2. How to extract app version from pubspec.yaml in a flutter app to use it in github actions running on windows? \- Stack Overflow, 访问时间为 九月 5, 2025， [https://stackoverflow.com/questions/75523265/how-to-extract-app-version-from-pubspec-yaml-in-a-flutter-app-to-use-it-in-githu](https://stackoverflow.com/questions/75523265/how-to-extract-app-version-from-pubspec-yaml-in-a-flutter-app-to-use-it-in-githu)  
3. mrbaseman/parse\_yaml: a simple yaml parser implemented in bash \- GitHub, 访问时间为 九月 5, 2025， [https://github.com/mrbaseman/parse\_yaml](https://github.com/mrbaseman/parse_yaml)  
4. Read YAML file from Bash script \- GitHub Gist, 访问时间为 九月 5, 2025， [https://gist.github.com/pkuczynski/8665367](https://gist.github.com/pkuczynski/8665367)  
5. How can I parse a YAML file from a Linux shell script? \- Stack Overflow, 访问时间为 九月 5, 2025， [https://stackoverflow.com/questions/5014632/how-can-i-parse-a-yaml-file-from-a-linux-shell-script](https://stackoverflow.com/questions/5014632/how-can-i-parse-a-yaml-file-from-a-linux-shell-script)  
6. Processing YAML Content With yq | Baeldung on Linux, 访问时间为 九月 5, 2025， [https://www.baeldung.com/linux/yq-utility-processing-yaml](https://www.baeldung.com/linux/yq-utility-processing-yaml)  
7. Parsing JSON and YAML Files with jq and yq in Shell Scripts | by Amareswer \- Medium, 访问时间为 九月 5, 2025， [https://medium.com/@amareswer/parsing-json-and-yaml-files-with-jq-and-yq-in-shell-scripts-39f1b3e3beb6](https://medium.com/@amareswer/parsing-json-and-yaml-files-with-jq-and-yq-in-shell-scripts-39f1b3e3beb6)  
8. Can I use a github action to rename a file? \- Stack Overflow, 访问时间为 九月 5, 2025， [https://stackoverflow.com/questions/70515210/can-i-use-a-github-action-to-rename-a-file](https://stackoverflow.com/questions/70515210/can-i-use-a-github-action-to-rename-a-file)  
9. GitHub Actions: Using non-fixed names in upload-artifact · community · Discussion \#26959, 访问时间为 九月 5, 2025， [https://github.com/orgs/community/discussions/26959](https://github.com/orgs/community/discussions/26959)  
10. actions/upload-artifact \- GitHub, 访问时间为 九月 5, 2025， [https://github.com/actions/upload-artifact](https://github.com/actions/upload-artifact)  
11. Store and share data with workflow artifacts \- GitHub Docs, 访问时间为 九月 5, 2025， [https://docs.github.com/actions/using-workflows/storing-workflow-data-as-artifacts](https://docs.github.com/actions/using-workflows/storing-workflow-data-as-artifacts)  
12. GH Release · Actions · GitHub Marketplace, 访问时间为 九月 5, 2025， [https://github.com/marketplace/actions/gh-release](https://github.com/marketplace/actions/gh-release)  
13. softprops/action-gh-release \- GitHub, 访问时间为 九月 5, 2025， [https://github.com/softprops/action-gh-release](https://github.com/softprops/action-gh-release)  
14. How to upload files and reuse them in GH Actions? \- Stack Overflow, 访问时间为 九月 5, 2025， [https://stackoverflow.com/questions/75511785/how-to-upload-files-and-reuse-them-in-gh-actions](https://stackoverflow.com/questions/75511785/how-to-upload-files-and-reuse-them-in-gh-actions)  
15. create-release \- Codesandbox, 访问时间为 九月 5, 2025， [http://codesandbox.io/p/github/b3b00/create-release](http://codesandbox.io/p/github/b3b00/create-release)  
16. REST API endpoints for releases and release assets \- GitHub Docs, 访问时间为 九月 5, 2025， [https://docs.github.com/en/rest/releases](https://docs.github.com/en/rest/releases)  
17. REST API endpoints for releases \- GitHub Docs, 访问时间为 九月 5, 2025， [https://docs.github.com/rest/releases/releases](https://docs.github.com/rest/releases/releases)  
18. upgrader | Flutter package \- Pub.dev, 访问时间为 九月 5, 2025， [https://pub.dev/packages/upgrader](https://pub.dev/packages/upgrader)  
19. upgrader \- Flutter package in App Update category, 访问时间为 九月 5, 2025， [https://fluttergems.dev/packages/upgrader/](https://fluttergems.dev/packages/upgrader/)  
20. A Flutter Package for Prompting App Upgrades | by Flutter News Hub \- Medium, 访问时间为 九月 5, 2025， [https://medium.com/@flutternewshub/upgrader-a-flutter-package-for-prompting-app-upgrades-651302757399](https://medium.com/@flutternewshub/upgrader-a-flutter-package-for-prompting-app-upgrades-651302757399)  
21. app\_version\_update | Flutter package \- Pub.dev, 访问时间为 九月 5, 2025， [https://pub.dev/packages/app\_version\_update](https://pub.dev/packages/app_version_update)  
22. ota\_update \- Flutter package in App Update category, 访问时间为 九月 5, 2025， [https://fluttergems.dev/packages/ota\_update/](https://fluttergems.dev/packages/ota_update/)  
23. ota\_update | Flutter package \- Pub.dev, 访问时间为 九月 5, 2025， [https://pub.dev/packages/ota\_update](https://pub.dev/packages/ota_update)  
24. app\_update | Flutter package \- Pub.dev, 访问时间为 九月 5, 2025， [https://pub.dev/packages/app\_update](https://pub.dev/packages/app_update)  
25. dio | Dart package \- Pub.dev, 访问时间为 九月 5, 2025， [https://pub.dev/packages/dio](https://pub.dev/packages/dio)  
26. How to download files in a flutter. | by Dipali Thakare \- Medium, 访问时间为 九月 5, 2025， [https://medium.com/@dipalithakare96/how-to-download-files-in-a-flutter-255f8963b28c](https://medium.com/@dipalithakare96/how-to-download-files-in-a-flutter-255f8963b28c)  
27. open\_filex | Flutter package \- Pub.dev, 访问时间为 九月 5, 2025， [https://pub.dev/packages/open\_filex](https://pub.dev/packages/open_filex)  
28. Use of the REQUEST\_INSTALL\_PACKAGES permission \- Play Console Help \- Google Help, 访问时间为 九月 5, 2025， [https://support.google.com/googleplay/android-developer/answer/12085295?hl=en](https://support.google.com/googleplay/android-developer/answer/12085295?hl=en)