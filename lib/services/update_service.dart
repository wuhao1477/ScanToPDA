import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pub_semver/pub_semver.dart';
import '../utils/network_helper.dart';

/// GitHub Release 信息数据模型
class ReleaseInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final String checksum;
  final int fileSize;

  ReleaseInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.checksum,
    required this.fileSize,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    // 提取版本号，移除 'v' 前缀
    final tagName = json['tag_name'] as String;
    final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;
    
    // 查找APK资源
    final assets = json['assets'] as List;
    String downloadUrl = '';
    int fileSize = 0;
    
    for (var asset in assets) {
      final name = asset['name'] as String;
      if (name.endsWith('.apk')) {
        downloadUrl = asset['browser_download_url'] as String;
        fileSize = asset['size'] as int? ?? 0;
        break;
      }
    }
    
    return ReleaseInfo(
      version: version,
      downloadUrl: downloadUrl,
      releaseNotes: json['body'] as String? ?? '版本更新',
      checksum: '', // 将从Release描述中解析
      fileSize: fileSize,
    );
  }
}

/// 版本更新服务
/// 
/// 提供基于GitHub Releases的OTA更新功能
class UpdateService {
  // 替换为实际的GitHub仓库信息
  static const String _githubOwner = 'wuhao'; // 请替换为实际用户名
  static const String _githubRepo = 'ScanToPDA'; // 请替换为实际仓库名
  static const String _apiUrl = 'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest';

  // 私有构造函数
  UpdateService._();

  // 单例实例
  static final UpdateService instance = UpdateService._();

  /// 获取最新发布信息
  /// 
  /// 返回最新版本的详细信息，如果获取失败返回null
  Future<ReleaseInfo?> getLatestReleaseInfo() async {
    try {
      debugPrint('🔍 正在检查最新版本...');
      
      // 检查网络连接
      final networkResult = await NetworkCheckResult.check();
      if (!networkResult.canUpdate) {
        debugPrint('❌ ${networkResult.message}');
        throw Exception(networkResult.message);
      }
      
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'ScanToPDA-UpdateService/1.0',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final releaseInfo = ReleaseInfo.fromJson(json);
        
        // 从Release描述中提取校验和
        final body = json['body'] as String? ?? '';
        final checksumMatch = RegExp(r'SHA256校验和.*?`([a-fA-F0-9]{64})`').firstMatch(body);
        if (checksumMatch != null) {
          return ReleaseInfo(
            version: releaseInfo.version,
            downloadUrl: releaseInfo.downloadUrl,
            releaseNotes: releaseInfo.releaseNotes,
            checksum: checksumMatch.group(1)!,
            fileSize: releaseInfo.fileSize,
          );
        }
        
        debugPrint('✅ 获取到最新版本: ${releaseInfo.version}');
        return releaseInfo;
      } else {
        debugPrint('❌ 获取版本信息失败: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 获取最新版本信息失败: $e');
      return null;
    }
  }

  /// 检查是否有可用更新
  /// 
  /// 比较最新版本与当前安装版本，返回是否需要更新
  Future<bool> isUpdateAvailable(String latestVersionStr) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionStr = packageInfo.version;

      debugPrint('📱 当前版本: $currentVersionStr');
      debugPrint('🌐 最新版本: $latestVersionStr');

      // 使用语义化版本比较
      final currentVersion = Version.parse(currentVersionStr);
      final latestVersion = Version.parse(latestVersionStr);
      
      final hasUpdate = latestVersion > currentVersion;
      debugPrint(hasUpdate ? '🆕 发现新版本可用' : '✅ 当前已是最新版本');
      
      return hasUpdate;
    } catch (e) {
      debugPrint('❌ 版本比较失败: $e');
      return false;
    }
  }

  /// 获取当前应用版本信息
  Future<PackageInfo> getCurrentAppInfo() async {
    return await PackageInfo.fromPlatform();
  }

  /// 下载并安装APK
  /// 
  /// [downloadUrl] APK下载地址
  /// [expectedChecksum] 期望的文件校验和（可选）
  /// [onProgress] 下载进度回调 (received, total)
  /// [onError] 错误回调
  Future<bool> downloadAndInstallApk({
    required String downloadUrl,
    String? expectedChecksum,
    Function(int received, int total)? onProgress,
    Function(String error)? onError,
  }) async {
    try {
      debugPrint('📥 开始下载APK: $downloadUrl');
      
      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      final fileName = 'scan_to_pda_update.apk';
      final filePath = '${tempDir.path}/$fileName';

      // 删除旧的APK文件（如果存在）
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ 删除旧的APK文件');
      }

      // 使用Dio下载文件，支持进度回调
      final dio = Dio();
      await dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total * 100).toInt();
            debugPrint('📊 下载进度: $progress% ($received/$total)');
            onProgress?.call(received, total);
          }
        },
      );

      debugPrint('✅ APK下载完成: $filePath');

      // 验证文件校验和（如果提供）
      if (expectedChecksum != null && expectedChecksum.isNotEmpty) {
        final isValid = await _verifyFileChecksum(filePath, expectedChecksum);
        if (!isValid) {
          onError?.call('文件校验失败，可能已被篡改');
          return false;
        }
        debugPrint('🔐 文件校验通过');
      }

      // 触发APK安装
      final result = await OpenFilex.open(filePath);
      if (result.type == ResultType.done) {
        debugPrint('🚀 APK安装程序已启动');
        return true;
      } else {
        final error = '无法打开APK文件: ${result.message}';
        debugPrint('❌ $error');
        onError?.call(error);
        return false;
      }
    } catch (e) {
      final error = '下载或安装失败: $e';
      debugPrint('❌ $error');
      onError?.call(error);
      return false;
    }
  }

  /// 验证文件SHA256校验和
  Future<bool> _verifyFileChecksum(String filePath, String expectedChecksum) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      const digest = sha256;
      final actualChecksum = digest.convert(bytes).toString();
      
      debugPrint('🔍 期望校验和: $expectedChecksum');
      debugPrint('🔍 实际校验和: $actualChecksum');
      
      return actualChecksum.toLowerCase() == expectedChecksum.toLowerCase();
    } catch (e) {
      debugPrint('❌ 校验和验证失败: $e');
      return false;
    }
  }

  /// 一键检查并更新
  /// 
  /// 检查更新并在发现新版本时返回更新信息，不自动下载
  Future<ReleaseInfo?> checkForUpdate() async {
    final releaseInfo = await getLatestReleaseInfo();
    if (releaseInfo == null) {
      return null;
    }

    final hasUpdate = await isUpdateAvailable(releaseInfo.version);
    return hasUpdate ? releaseInfo : null;
  }

  /// 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}
