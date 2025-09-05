import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

/// 更新管理器
/// 
/// 负责管理自动更新检查、用户偏好设置等高级功能
class UpdateManager {
  static const String _keyAutoCheckUpdate = 'auto_check_update';
  static const String _keyLastCheckTime = 'last_check_time';
  static const String _keySkippedVersion = 'skipped_version';
  static const String _keyUpdateFrequency = 'update_frequency';
  
  // 更新检查频率（小时）
  static const int _defaultCheckFrequency = 24;
  
  UpdateManager._();
  static final UpdateManager instance = UpdateManager._();

  /// 获取自动检查更新设置
  Future<bool> getAutoCheckEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoCheckUpdate) ?? true; // 默认开启
  }

  /// 设置自动检查更新
  Future<void> setAutoCheckEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoCheckUpdate, enabled);
  }

  /// 获取更新检查频率（小时）
  Future<int> getCheckFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUpdateFrequency) ?? _defaultCheckFrequency;
  }

  /// 设置更新检查频率
  Future<void> setCheckFrequency(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUpdateFrequency, hours);
  }

  /// 获取上次检查时间
  Future<DateTime?> getLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_keyLastCheckTime);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  /// 更新上次检查时间
  Future<void> updateLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastCheckTime, DateTime.now().millisecondsSinceEpoch);
  }

  /// 获取跳过的版本
  Future<String?> getSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySkippedVersion);
  }

  /// 设置跳过的版本
  Future<void> setSkippedVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySkippedVersion, version);
  }

  /// 清除跳过的版本
  Future<void> clearSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySkippedVersion);
  }

  /// 检查是否应该进行自动更新检查
  Future<bool> shouldCheckForUpdate() async {
    final autoCheckEnabled = await getAutoCheckEnabled();
    if (!autoCheckEnabled) return false;

    final lastCheckTime = await getLastCheckTime();
    if (lastCheckTime == null) return true;

    final checkFrequency = await getCheckFrequency();
    final now = DateTime.now();
    final timeDifference = now.difference(lastCheckTime);
    
    return timeDifference.inHours >= checkFrequency;
  }

  /// 静默检查更新（应用启动时调用）
  Future<void> silentCheckForUpdate(BuildContext context) async {
    if (!await shouldCheckForUpdate()) return;

    try {
      debugPrint('🔍 执行静默更新检查...');
      final releaseInfo = await UpdateService.instance.checkForUpdate();
      await updateLastCheckTime();

      if (releaseInfo != null && context.mounted) {
        final skippedVersion = await getSkippedVersion();
        
        // 如果用户之前跳过了这个版本，则不再提示
        if (skippedVersion == releaseInfo.version) {
          debugPrint('⏭️ 用户已跳过版本 ${releaseInfo.version}');
          return;
        }

        // 显示更新提示
        _showUpdateNotification(context, releaseInfo);
      }
    } catch (e) {
      debugPrint('❌ 静默更新检查失败: $e');
    }
  }

  /// 显示更新通知（非阻塞式）
  void _showUpdateNotification(BuildContext context, ReleaseInfo releaseInfo) {
    // 使用 SnackBar 显示非阻塞式通知
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('发现新版本', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('版本 ${releaseInfo.version} 可用'),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: '查看',
          textColor: Colors.white,
          onPressed: () => _showUpdateOptionsDialog(context, releaseInfo),
        ),
      ),
    );
  }

  /// 显示更新选项对话框
  void _showUpdateOptionsDialog(BuildContext context, ReleaseInfo releaseInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发现新版本'),
        content: Text('版本 ${releaseInfo.version} 现已可用。您希望：'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setSkippedVersion(releaseInfo.version);
            },
            child: const Text('跳过此版本'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍后提醒'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              showUpdateDialog(context, releaseInfo);
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  /// 手动检查更新（设置页面调用）
  Future<ReleaseInfo?> manualCheckForUpdate() async {
    final releaseInfo = await UpdateService.instance.checkForUpdate();
    await updateLastCheckTime();
    
    // 手动检查时清除跳过的版本设置
    if (releaseInfo != null) {
      await clearSkippedVersion();
    }
    
    return releaseInfo;
  }
}

/// 更新设置页面
class UpdateSettingsPage extends StatefulWidget {
  const UpdateSettingsPage({Key? key}) : super(key: key);

  @override
  State<UpdateSettingsPage> createState() => _UpdateSettingsPageState();
}

class _UpdateSettingsPageState extends State<UpdateSettingsPage> {
  bool _autoCheckEnabled = true;
  int _checkFrequency = 24;
  DateTime? _lastCheckTime;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final manager = UpdateManager.instance;
    final autoCheck = await manager.getAutoCheckEnabled();
    final frequency = await manager.getCheckFrequency();
    final lastCheck = await manager.getLastCheckTime();

    if (mounted) {
      setState(() {
        _autoCheckEnabled = autoCheck;
        _checkFrequency = frequency;
        _lastCheckTime = lastCheck;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('更新设置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('自动检查更新'),
              subtitle: const Text('应用启动时自动检查新版本'),
              value: _autoCheckEnabled,
              onChanged: (value) async {
                await UpdateManager.instance.setAutoCheckEnabled(value);
                setState(() {
                  _autoCheckEnabled = value;
                });
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('检查频率'),
                  subtitle: Text('每 $_checkFrequency 小时检查一次'),
                  trailing: const Icon(Icons.schedule),
                ),
                Slider(
                  value: _checkFrequency.toDouble(),
                  min: 1,
                  max: 168, // 7天
                  divisions: 23,
                  label: '$_checkFrequency 小时',
                  onChanged: _autoCheckEnabled ? (value) {
                    setState(() {
                      _checkFrequency = value.toInt();
                    });
                  } : null,
                  onChangeEnd: (value) async {
                    await UpdateManager.instance.setCheckFrequency(value.toInt());
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1小时', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text('7天', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (_lastCheckTime != null)
            Card(
              child: ListTile(
                title: const Text('上次检查'),
                subtitle: Text(_formatDateTime(_lastCheckTime!)),
                leading: const Icon(Icons.history),
              ),
            ),
          
          const SizedBox(height: 24),
          
          ElevatedButton.icon(
            onPressed: () => _checkNow(),
            icon: const Icon(Icons.refresh),
            label: const Text('立即检查更新'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} 分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} 小时前';
    } else {
      return '${difference.inDays} 天前';
    }
  }

  void _checkNow() async {
    // 显示加载指示器
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在检查更新...'),
          ],
        ),
      ),
    );

    try {
      final releaseInfo = await UpdateManager.instance.manualCheckForUpdate();
      
      if (mounted) {
        Navigator.of(context).pop(); // 关闭加载对话框
        
        if (releaseInfo != null) {
          showUpdateDialog(context, releaseInfo);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已是最新版本'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        // 刷新界面
        _loadSettings();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('检查更新失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
