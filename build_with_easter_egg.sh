#!/bin/bash

# ScanToPDA 彩蛋功能构建脚本
# 此脚本演示如何在构建时注入彩蛋配置

set -e  # 遇到错误时退出

echo "🚀 构建 ScanToPDA 应用（带彩蛋配置）..."

# 检查Flutter环境
if ! command -v flutter &> /dev/null; then
    echo "❌ 错误: 未找到 Flutter 命令，请确保 Flutter 已正确安装并添加到 PATH"
    exit 1
fi

echo "✅ Flutter 环境检查通过: $(flutter --version | head -n 1)"

# 检查是否在正确的项目目录
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ 错误: 未找到 pubspec.yaml 文件，请在 Flutter 项目根目录下运行此脚本"
    exit 1
fi

# 检查是否是 ScanToPDA 项目
if ! grep -q "name: scan_to_pda" pubspec.yaml; then
    echo "⚠️  警告: 这似乎不是 ScanToPDA 项目，继续构建可能会出错"
    read -p "是否继续？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "✅ 项目检查通过"

# 检查参数
if [ $# -eq 0 ]; then
    echo "用法: $0 [app|url] [target]"
    echo ""
    echo "示例:"
    echo "  $0 app com.tencent.mm              # 扫码后打开微信"
    echo "  $0 url https://www.baidu.com       # 扫码后打开百度"
    echo ""
    exit 1
fi

ACTION_TYPE=$1
TARGET=$2

# 验证参数
if [ "$ACTION_TYPE" != "app" ] && [ "$ACTION_TYPE" != "url" ]; then
    echo "错误: 操作类型必须是 'app' 或 'url'"
    exit 1
fi

if [ -z "$TARGET" ]; then
    echo "错误: 请提供目标（应用包名或网址）"
    exit 1
fi

# 构建参数
BUILD_ARGS="--dart-define=EASTER_EGG_ACTION_TYPE=$ACTION_TYPE"

if [ "$ACTION_TYPE" = "app" ]; then
    BUILD_ARGS="$BUILD_ARGS --dart-define=EASTER_EGG_TARGET_PACKAGE=$TARGET"
    # 尝试获取应用名称（可选）
    case "$TARGET" in
        "com.tencent.mm") APP_NAME="微信" ;;
        "com.taobao.taobao") APP_NAME="淘宝" ;;
        "com.eg.android.AlipayGphone") APP_NAME="支付宝" ;;
        "com.android.chrome") APP_NAME="Chrome浏览器" ;;
        *) APP_NAME="自定义应用" ;;
    esac
    BUILD_ARGS="$BUILD_ARGS --dart-define=EASTER_EGG_SELECTED_APP_NAME=$APP_NAME"
    echo "配置：扫码后打开应用 $APP_NAME ($TARGET)"
elif [ "$ACTION_TYPE" = "url" ]; then
    BUILD_ARGS="$BUILD_ARGS --dart-define=EASTER_EGG_TARGET_URL=$TARGET"
    echo "配置：扫码后打开网址 $TARGET"
fi

echo ""
echo "构建参数: $BUILD_ARGS"
echo ""

# 清理并获取依赖
echo "📦 获取项目依赖..."
flutter clean
flutter pub get

# 执行构建
echo "🔨 开始构建 APK..."
flutter build apk $BUILD_ARGS

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 构建完成！"
    echo ""
    echo "APK 位置: build/app/outputs/flutter-apk/app-release.apk"
    echo ""
    echo "彩蛋配置已注入："
    echo "  - 操作类型: $ACTION_TYPE"
    if [ "$ACTION_TYPE" = "app" ]; then
        echo "  - 目标应用: $APP_NAME ($TARGET)"
    else
        echo "  - 目标网址: $TARGET"
    fi
    echo ""
    echo "用户可以通过点击关于页面中的开发者名称 10 次来访问彩蛋设置。"
else
    echo ""
    echo "❌ 构建失败！"
    exit 1
fi
