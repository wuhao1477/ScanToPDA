# ScanToPDA

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-green.svg)](https://github.com/wuhao1477/ScanToPDA)

ScanToPDA 是一个专业的 Flutter 扫码助手应用，专为 PDA 设备和扫码枪设计，支持蓝牙连接、无障碍服务监听、悬浮窗显示等功能。

## ✨ 功能特性

- 📱 **蓝牙扫码监听** - 实时监听蓝牙扫码枪输入
- 🔗 **无障碍服务** - 全局按键监听，确保后台正常工作
- 📊 **悬浮窗显示** - 便捷的悬浮窗界面，随时查看扫码状态
- 🔄 **权限管理** - 智能权限检测和引导设置
- 🎯 **后台服务** - 稳定的后台服务支持
- 🐛 **崩溃日志** - 自动记录应用崩溃信息，便于问题排查
- 🔒 **多版本兼容** - 支持 Android 4-15 全版本兼容

## 🛠 技术栈

- **前端**: Flutter 3.0+, Dart
- **平台**: Android (主要), iOS
- **通信**: Bluetooth Low Energy (BLE), MethodChannel
- **服务**: Android Foreground Service, Accessibility Service
- **数据库**: SQLite (崩溃日志存储)
- **权限**: Runtime Permissions, Special Permissions

## 🚀 快速开始

### 环境要求

- Flutter 3.0+
- Dart 2.19+
- Android SDK (API 21+)
- Android Studio / VS Code

### 安装步骤

1. **克隆项目**
   ```bash
   git clone https://github.com/wuhao1477/ScanToPDA.git
   cd ScanToPDA
   ```

2. **安装依赖**
   ```bash
   flutter pub get
   ```

3. **运行项目**
   ```bash
   flutter run
   ```

### 权限配置

应用需要以下权限才能正常工作：

- 🔵 **蓝牙权限** (必需) - 用于连接扫码枪设备
- 📍 **位置权限** (Android 6.0-11需要) - 蓝牙扫描需要
- 🪟 **悬浮窗权限** (可选) - 显示悬浮状态窗口
- ♿ **无障碍服务** (必需) - 监听键盘输入事件

首次启动应用会自动引导您完成权限设置。

## 📖 使用说明

1. **首次启动** - 按照权限引导完成必要权限设置
2. **启动服务** - 在主界面开启扫码服务
3. **连接设备** - 通过蓝牙连接您的扫码枪
4. **开始扫码** - 扫码结果将实时显示在应用中

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

### 开发规范

1. 遵循 Flutter/Dart 编码规范
2. 提交前请运行 `flutter analyze`
3. 新功能需要添加相应的测试
4. 提交信息请使用中文，格式清晰

## 📄 开源协议

本项目采用 [Apache License 2.0](LICENSE) 开源协议。

### 协议要点

✅ **允许**:
- 商业使用
- 修改代码
- 分发代码
- 私人使用

❗ **要求**:
- 保留版权声明
- 包含许可证副本
- 标明代码修改
- 注明原项目来源

❌ **禁止**:
- 使用商标
- 承担责任

## 👨‍💻 开发者

**wuhao1477**
- GitHub: [@wuhao1477](https://github.com/wuhao1477)
- 项目地址: [ScanToPDA](https://github.com/wuhao1477/ScanToPDA)

## 🙏 致谢

感谢以下开源项目的支持：

- [Flutter](https://flutter.dev/) - UI 框架
- [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) - 蓝牙通信
- [permission_handler](https://pub.dev/packages/permission_handler) - 权限管理
- [share_plus](https://pub.dev/packages/share_plus) - 分享功能

## 📞 支持

如果您在使用过程中遇到问题，请：

1. 查看 [使用说明](https://github.com/wuhao1477/ScanToPDA/wiki)
2. 搜索 [已有 Issues](https://github.com/wuhao1477/ScanToPDA/issues)
3. 创建 [新的 Issue](https://github.com/wuhao1477/ScanToPDA/issues/new)

---

⭐ 如果这个项目对您有帮助，请给个 Star 支持一下！
