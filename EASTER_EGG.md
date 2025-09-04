# 🥚 彩蛋功能说明

ScanToPDA 应用包含一个隐藏的彩蛋功能，允许配置扫码后的后置操作。

## 功能特性

- **自动打开应用**：扫码成功后自动启动指定的应用
- **自动打开网址**：扫码成功后自动在浏览器中打开指定网址
- **构建时注入**：支持在构建时通过环境变量预设配置
- **用户可配置**：用户可以在界面中修改默认配置

## 如何访问彩蛋功能

1. 打开应用，进入"关于应用"页面
2. 连续点击开发者名称 **10 次**
3. 会弹出彩蛋解锁提示
4. 点击"进入设置"即可配置后置操作

## 配置选项

### 操作类型

- **无操作**：扫码后不执行任何额外操作（默认）
- **打开应用**：扫码后自动打开指定的应用
- **打开网址**：扫码后自动在浏览器中打开指定网址

### 应用选择

- 从已安装应用列表中选择
- 手动输入应用包名
- 支持常见应用的智能图标识别

### 网址配置

- 支持 HTTP/HTTPS 网址
- 支持自定义协议（如 `myapp://action`）
- 支持本地网址（如 `http://192.168.1.100:8080`）

## 构建时注入配置

### 使用脚本构建

项目提供了便捷的构建脚本：

```bash
# 构建时配置打开微信
./build_with_easter_egg.sh app com.tencent.mm

# 构建时配置打开百度
./build_with_easter_egg.sh url https://www.baidu.com
```

### 手动构建命令

```bash
# 配置打开应用
flutter build apk \
  --dart-define=EASTER_EGG_ACTION_TYPE=app \
  --dart-define=EASTER_EGG_TARGET_PACKAGE=com.tencent.mm \
  --dart-define=EASTER_EGG_SELECTED_APP_NAME=微信

# 配置打开网址
flutter build apk \
  --dart-define=EASTER_EGG_ACTION_TYPE=url \
  --dart-define=EASTER_EGG_TARGET_URL=https://www.example.com
```

### 支持的环境变量

| 变量名 | 说明 | 示例值 |
|--------|------|--------|
| `EASTER_EGG_ACTION_TYPE` | 操作类型 | `none`, `app`, `url` |
| `EASTER_EGG_TARGET_PACKAGE` | 目标应用包名 | `com.tencent.mm` |
| `EASTER_EGG_TARGET_URL` | 目标网址 | `https://www.example.com` |
| `EASTER_EGG_SELECTED_APP_NAME` | 应用显示名称 | `微信` |

## GitHub Actions 自动构建

项目提供了 GitHub Actions 工作流，支持在线构建带彩蛋配置的 APK：

1. 进入项目的 GitHub 页面
2. 点击 "Actions" 标签
3. 选择 "Build APK with Easter Egg Configuration"
4. 点击 "Run workflow"
5. 填写配置参数
6. 等待构建完成并下载 APK

## 常见应用包名

| 应用名称 | 包名 |
|----------|------|
| 微信 | `com.tencent.mm` |
| QQ | `com.tencent.mobileqq` |
| 支付宝 | `com.eg.android.AlipayGphone` |
| 淘宝 | `com.taobao.taobao` |
| 抖音 | `com.ss.android.ugc.aweme` |
| Chrome | `com.android.chrome` |

## 技术实现

### 前端实现

- 使用 `String.fromEnvironment()` 读取编译时环境变量
- 使用 `SharedPreferences` 存储用户配置
- 用户配置优先于环境变量默认值

### Android 端实现

- 通过 `PackageManager` 获取已安装应用列表
- 使用 `Intent` 启动指定应用
- 支持 `url_launcher` 打开网址

### 权限要求

- `QUERY_ALL_PACKAGES`：查询已安装应用（Android 11+）
- 应用列表查询权限在 `AndroidManifest.xml` 中配置

## 安全说明

- 彩蛋功能是隐藏功能，需要用户主动发现和配置
- 不会收集或上传任何用户数据
- 所有配置都存储在本地设备上
- 构建时注入的配置是只读的默认值，用户可以修改

## 使用场景

- **企业定制**：为特定企业构建定制版本，扫码后自动打开企业应用
- **展会演示**：扫码后自动打开产品介绍页面
- **教育培训**：扫码后自动打开学习资料
- **个人便利**：根据个人习惯配置常用操作

## 注意事项

1. 彩蛋功能仅在用户主动发现和配置后生效
2. 如果目标应用未安装，会显示错误提示
3. 网址必须是有效的 URL 格式
4. 构建时注入的配置会作为默认值，用户仍可修改
5. 清除应用数据会重置为环境变量默认值
