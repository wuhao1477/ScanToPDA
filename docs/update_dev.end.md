# ScanToPDA 版本更新服务开发计划

## 📋 项目概述

基于对三个AI分析文档（update_dev.1.md、update_dev.2.md、update_dev.3.md）的综合分析，制定了这份全面的开发计划。本计划旨在为 ScanToPDA 项目建立一个完整的自动化构建、发布和版本更新系统。

### 🎯 核心目标

1. **自动化CI/CD流程**：实现基于Git标签的自动构建和发布
2. **动态版本管理**：APK文件自动以"应用名-版本号"格式命名
3. **应用内更新服务**：基于GitHub Releases的OTA更新机制
4. **生产级安全性**：包含文件校验和验证等安全措施

## 🏗️ 系统架构

```
开发者推送标签 → GitHub Actions → 构建APK → 创建Release → 用户应用检查更新 → 下载安装
     ↓              ↓           ↓         ↓              ↓           ↓
   v1.0.0     动态版本提取   重命名APK   发布到GitHub   版本比较      OTA更新
```

## 📅 实施计划

### 第一阶段：优化CI/CD工作流 🔧

#### 1.1 增强版本提取机制
- 使用 `yq` 工具可靠解析 `pubspec.yaml`
- 提取应用名称和版本号作为环境变量
- 支持语义化版本控制（SemVer）

#### 1.2 实现动态APK命名
- APK文件格式：`scan_to_pda-v0.0.1.apk`
- 支持彩蛋构建和标准构建两种模式
- 自动生成文件校验和（SHA256）

#### 1.3 完善Release自动化
- 基于Git标签自动触发发布
- Release标题格式：`ScanToPDA v0.0.1`
- 包含详细的更新说明和校验和信息

### 第二阶段：Flutter端更新服务 📱

#### 2.1 核心依赖集成
选择轻量级、高度兼容的插件组合：
- `package_info_plus`: 获取当前版本信息
- `http`: GitHub API请求
- `pub_semver`: 语义化版本比较
- `dio`: 带进度的文件下载
- `path_provider`: 文件存储路径
- `open_filex`: APK安装触发

#### 2.2 UpdateService核心类
- 单例模式设计，全应用可用
- 支持版本检查、下载进度、安装引导
- 完善的错误处理和用户体验

#### 2.3 用户界面集成
- 非阻塞式更新通知
- 实时下载进度显示
- 优雅的错误提示和重试机制

### 第三阶段：安全性和最佳实践 🔒

#### 3.1 文件完整性校验
- CI阶段生成SHA256校验和
- 客户端下载后验证文件完整性
- 防止中间人攻击和文件篡改

#### 3.2 权限管理
- Android "安装未知应用"权限处理
- 网络权限配置
- 用户授权引导

#### 3.3 版本管理规范
- 语义化版本控制（x.y.z）
- Git标签命名规范（v1.0.0）
- 预发布版本支持（beta、rc）

## 🔧 技术实现细节

### GitHub Actions 工作流优化

**关键改进点：**
1. 使用 `yq` 替代不可靠的 shell 解析
2. 动态生成APK文件名和Release标题
3. 分离构建和发布作业，提高模块化
4. 支持手动触发和标签触发两种模式

**新增步骤：**
- 安装 yq 工具
- 提取应用元数据
- 重命名APK文件
- 生成校验和文件
- 优化Release创建逻辑

### Flutter 更新服务架构

**核心组件：**
1. **ReleaseInfo 数据模型**：封装版本信息、下载链接、更新说明
2. **版本比较逻辑**：基于pub_semver的精确版本比较
3. **下载管理器**：支持断点续传、进度回调的文件下载
4. **安装引导器**：调用系统安装程序的封装

**API交互流程：**
```
GET /repos/用户名/scan_to_pda/releases/latest
→ 解析 tag_name 和 assets
→ 版本比较
→ 用户确认
→ 下载APK
→ 校验文件
→ 触发安装
```

## 📦 依赖配置

### pubspec.yaml 新增依赖
```yaml
dependencies:
  # 版本更新相关
  package_info_plus: ^5.0.0
  http: ^1.2.1
  pub_semver: ^2.1.4
  dio: ^5.4.3+1
  path_provider: ^2.1.3
  open_filex: ^4.4.0
```

### Android 权限配置
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
```

## 🚀 使用流程

### 开发者发布流程
1. 更新 `pubspec.yaml` 中的版本号
2. 提交代码并推送
3. 创建并推送Git标签：`git tag v1.0.0 && git push origin v1.0.0`
4. GitHub Actions自动构建并发布到Releases

### 用户更新流程
1. 打开应用，自动检查更新（或手动检查）
2. 发现新版本时显示更新对话框
3. 用户确认后开始下载，显示进度
4. 下载完成后自动打开安装程序
5. 用户确认安装完成更新

## ⚠️ 重要注意事项

### 安全考虑
- 所有下载文件必须进行SHA256校验
- 使用HTTPS确保传输安全
- 用户必须手动授权"安装未知应用"权限

### 兼容性
- 仅支持Android平台（iOS有严格限制）
- 需要Android 8.0+支持外部APK安装
- 确保网络连接稳定性

### 版本管理
- 严格遵循语义化版本控制
- 预发布版本使用prerelease标记
- 保持Git标签与pubspec.yaml版本同步

## 📈 预期效果

1. **开发效率提升**：自动化发布流程，减少手动操作
2. **用户体验优化**：应用内直接更新，无需访问GitHub
3. **版本管理规范**：标准化的版本控制和发布流程
4. **安全性保障**：文件完整性校验，防止安全风险

## 🔄 后续优化方向

1. **增量更新**：支持差分包更新，减少下载大小
2. **多渠道发布**：支持不同渠道的版本分发
3. **更新策略**：支持强制更新、推荐更新等策略
4. **统计分析**：集成更新成功率、用户行为分析

---

**本开发计划综合了三个AI文档的核心建议，形成了一个完整、可行的实施方案。建议按阶段逐步实施，确保每个阶段都经过充分测试后再进入下一阶段。**
