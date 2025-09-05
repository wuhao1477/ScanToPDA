import 'dart:io';
import 'package:flutter/foundation.dart';

/// 网络状态辅助工具
class NetworkHelper {
  NetworkHelper._();
  
  /// 检查网络连接状态
  static Future<bool> isConnected() async {
    try {
      final result = await InternetAddress.lookup('api.github.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('❌ 网络连接检查失败: $e');
      return false;
    }
  }

  /// 检查GitHub API可访问性
  static Future<bool> isGitHubAccessible() async {
    try {
      final result = await InternetAddress.lookup('api.github.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        return false;
      }

      // 进一步检查HTTP连接
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      
      final request = await client.getUrl(Uri.parse('https://api.github.com'));
      final response = await request.close();
      client.close();
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ GitHub API 可访问性检查失败: $e');
      return false;
    }
  }

  /// 获取网络状态描述
  static Future<String> getNetworkStatus() async {
    if (await isConnected()) {
      if (await isGitHubAccessible()) {
        return '网络连接正常';
      } else {
        return '网络已连接，但无法访问GitHub';
      }
    } else {
      return '网络连接不可用';
    }
  }

  /// 检查是否为计费网络（移动数据）
  /// 注意：这需要额外的插件支持，这里提供接口
  static Future<bool> isMeteredConnection() async {
    // 这里可以集成 connectivity_plus 插件来检查网络类型
    // 暂时返回 false，表示假设为非计费网络
    return false;
  }
}

/// 网络状态枚举
enum NetworkStatus {
  connected,
  disconnected,
  githubUnavailable,
  metered,
}

/// 网络状态检查结果
class NetworkCheckResult {
  final NetworkStatus status;
  final String message;
  final bool canUpdate;

  const NetworkCheckResult({
    required this.status,
    required this.message,
    required this.canUpdate,
  });

  static Future<NetworkCheckResult> check() async {
    if (!await NetworkHelper.isConnected()) {
      return const NetworkCheckResult(
        status: NetworkStatus.disconnected,
        message: '网络连接不可用，请检查网络设置',
        canUpdate: false,
      );
    }

    if (!await NetworkHelper.isGitHubAccessible()) {
      return const NetworkCheckResult(
        status: NetworkStatus.githubUnavailable,
        message: '无法访问GitHub服务器，请稍后重试',
        canUpdate: false,
      );
    }

    if (await NetworkHelper.isMeteredConnection()) {
      return const NetworkCheckResult(
        status: NetworkStatus.metered,
        message: '当前使用移动数据网络，下载可能产生流量费用',
        canUpdate: true,
      );
    }

    return const NetworkCheckResult(
      status: NetworkStatus.connected,
      message: '网络连接正常',
      canUpdate: true,
    );
  }
}
