import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// 崩溃日志数据模型
class CrashLogData {
  final int id;
  final int timestamp;
  final String formattedTime;
  final String crashType;
  final String errorMessage;
  final String shortDescription;
  final String stackTrace;
  final String deviceInfo;
  final String appVersion;
  final String androidVersion;
  final String deviceModel;
  final int availableMemory;
  final int totalMemory;
  final bool isRead;

  CrashLogData({
    required this.id,
    required this.timestamp,
    required this.formattedTime,
    required this.crashType,
    required this.errorMessage,
    required this.shortDescription,
    required this.stackTrace,
    required this.deviceInfo,
    required this.appVersion,
    required this.androidVersion,
    required this.deviceModel,
    required this.availableMemory,
    required this.totalMemory,
    required this.isRead,
  });

  factory CrashLogData.fromMap(Map<String, dynamic> map) {
    return CrashLogData(
      id: map['id'] ?? 0,
      timestamp: map['timestamp'] ?? 0,
      formattedTime: map['formattedTime'] ?? '',
      crashType: map['crashType'] ?? '',
      errorMessage: map['errorMessage'] ?? '',
      shortDescription: map['shortDescription'] ?? '',
      stackTrace: map['stackTrace'] ?? '',
      deviceInfo: map['deviceInfo'] ?? '',
      appVersion: map['appVersion'] ?? '',
      androidVersion: map['androidVersion'] ?? '',
      deviceModel: map['deviceModel'] ?? '',
      availableMemory: map['availableMemory'] ?? 0,
      totalMemory: map['totalMemory'] ?? 0,
      isRead: map['isRead'] ?? false,
    );
  }

  /// 获取崩溃类型对应的图标
  IconData get typeIcon {
    switch (crashType) {
      case 'OutOfMemory':
        return Icons.memory;
      case 'JavaException':
        return Icons.bug_report;
      case 'ANR':
        return Icons.hourglass_empty;
      case 'FlutterError':
        return Icons.flutter_dash;
      case 'NativeCrash':
        return Icons.code;
      default:
        return Icons.error;
    }
  }

  /// 获取崩溃类型对应的颜色
  Color get typeColor {
    switch (crashType) {
      case 'OutOfMemory':
        return Colors.red;
      case 'JavaException':
        return Colors.orange;
      case 'ANR':
        return Colors.amber;
      case 'FlutterError':
        return Colors.blue;
      case 'NativeCrash':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  /// 获取崩溃类型的中文名称
  String get typeDisplayName {
    switch (crashType) {
      case 'OutOfMemory':
        return '内存溢出';
      case 'JavaException':
        return 'Java异常';
      case 'ANR':
        return '应用无响应';
      case 'FlutterError':
        return 'Flutter错误';
      case 'NativeCrash':
        return '原生崩溃';
      case 'CaughtException':
        return '捕获异常';
      default:
        return '未知错误';
    }
  }
}

/// 崩溃日志页面
class CrashLogPage extends StatefulWidget {
  const CrashLogPage({Key? key}) : super(key: key);

  @override
  State<CrashLogPage> createState() => _CrashLogPageState();
}

class _CrashLogPageState extends State<CrashLogPage> {
  static const MethodChannel _crashLogChannel = MethodChannel('com.example.scan_to_pda/crash_log');

  List<CrashLogData> _crashLogs = [];
  List<CrashLogData>? _filteredLogsCache;
  String _lastSearchQuery = '';
  String _lastSelectedFilter = 'all';
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadCrashLogs();
  }
  
  @override
  void dispose() {
    // 虽然当前没有需要释放的资源，但保持良好的编程习惯
    super.dispose();
  }

  /// 加载崩溃日志
  Future<void> _loadCrashLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final List<dynamic>? result = await _crashLogChannel.invokeMethod('getCrashLogs');
      if (result != null) {
        setState(() {
          _crashLogs = result.map((item) => CrashLogData.fromMap(Map<String, dynamic>.from(item))).toList();
          // 清除缓存，强制重新计算过滤结果
          _filteredLogsCache = null;
        });
      }
    } on PlatformException catch (e) {
      _showMessage('加载崩溃日志失败: ${e.message}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 标记日志为已读
  Future<void> _markAsRead(int id) async {
    try {
      await _crashLogChannel.invokeMethod('markCrashLogAsRead', {'id': id});
      _loadCrashLogs(); // 重新加载数据
    } on PlatformException catch (e) {
      _showMessage('标记失败: ${e.message}');
    }
  }

  /// 删除单个日志
  Future<void> _deleteCrashLog(int id) async {
    try {
      final bool? success = await _crashLogChannel.invokeMethod('deleteCrashLog', {'id': id});
      if (success == true) {
        _showMessage('删除成功');
        _loadCrashLogs();
      } else {
        _showMessage('删除失败');
      }
    } on PlatformException catch (e) {
      _showMessage('删除失败: ${e.message}');
    }
  }

  /// 清空所有日志
  Future<void> _clearAllCrashLogs() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有崩溃日志吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final bool? success = await _crashLogChannel.invokeMethod('clearAllCrashLogs');
        if (success == true) {
          _showMessage('清空成功');
          _loadCrashLogs();
        } else {
          _showMessage('清空失败');
        }
      } on PlatformException catch (e) {
        _showMessage('清空失败: ${e.message}');
      }
    }
  }

  /// 导出日志
  Future<void> _exportCrashLog(CrashLogData crashLog, String format) async {
    try {
      final String? exportData = await _crashLogChannel.invokeMethod('exportCrashLog', {
        'id': crashLog.id,
        'format': format,
      });

      if (exportData != null) {
        final String fileName = 'crash_log_${crashLog.id}_${DateTime.now().millisecondsSinceEpoch}.$format';
        
        // 使用系统分享功能
        await Share.share(
          exportData,
          subject: '崩溃日志 - ${crashLog.typeDisplayName}',
        );
        
        _showMessage('日志已导出');
      }
    } on PlatformException catch (e) {
      _showMessage('导出失败: ${e.message}');
    }
  }

  /// 测试崩溃
  Future<void> _testCrash() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('测试崩溃'),
        content: const Text('确定要创建一个测试崩溃吗？这将生成一条测试崩溃日志。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _crashLogChannel.invokeMethod('testCrash');
        _showMessage('测试崩溃已创建，请等待几秒后刷新');
        
        // 延迟刷新，给系统时间处理崩溃
        Future.delayed(const Duration(seconds: 2), () {
          _loadCrashLogs();
        });
      } on PlatformException catch (e) {
        _showMessage('测试崩溃失败: ${e.message}');
      }
    }
  }

  /// 过滤日志（带缓存优化）
  List<CrashLogData> get _filteredCrashLogs {
    // 检查是否需要重新计算
    if (_filteredLogsCache != null && 
        _lastSearchQuery == _searchQuery && 
        _lastSelectedFilter == _selectedFilter) {
      return _filteredLogsCache!;
    }

    List<CrashLogData> filtered = _crashLogs;

    // 按类型过滤
    if (_selectedFilter != 'all') {
      if (_selectedFilter == 'unread') {
        filtered = filtered.where((log) => !log.isRead).toList();
      } else {
        filtered = filtered.where((log) => log.crashType == _selectedFilter).toList();
      }
    }

    // 按搜索关键词过滤
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((log) {
        return log.errorMessage.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            log.typeDisplayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            log.deviceModel.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // 缓存结果
    _filteredLogsCache = filtered;
    _lastSearchQuery = _searchQuery;
    _lastSelectedFilter = _selectedFilter;

    return filtered;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _filteredCrashLogs;

    return Scaffold(
      appBar: AppBar(
        title: Text('崩溃日志 (${_crashLogs.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCrashLogs,
            tooltip: '刷新',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clear_all':
                  _clearAllCrashLogs();
                  break;
                case 'test_crash':
                  _testCrash();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'test_crash',
                child: ListTile(
                  leading: Icon(Icons.bug_report),
                  title: Text('测试崩溃'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep, color: Colors.red),
                  title: Text('清空所有日志', style: TextStyle(color: Colors.red)),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索和过滤栏
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                // 搜索框
                TextField(
                  decoration: InputDecoration(
                    hintText: '搜索错误信息、类型或设备型号...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                
                // 过滤器
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', '全部', Icons.list),
                      _buildFilterChip('unread', '未读', Icons.fiber_new),
                      _buildFilterChip('OutOfMemory', '内存溢出', Icons.memory),
                      _buildFilterChip('JavaException', 'Java异常', Icons.bug_report),
                      _buildFilterChip('ANR', 'ANR', Icons.hourglass_empty),
                      _buildFilterChip('FlutterError', 'Flutter错误', Icons.flutter_dash),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 日志列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _crashLogs.isEmpty ? Icons.check_circle : Icons.search_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _crashLogs.isEmpty ? '暂无崩溃日志' : '没有找到匹配的日志',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            if (_crashLogs.isEmpty) ...[
                              const SizedBox(height: 8),
                              const Text(
                                '这是一个好消息！',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) {
                          final crashLog = filteredLogs[index];
                          return _buildCrashLogItem(crashLog);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  /// 构建过滤器芯片
  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = selected ? value : 'all';
          });
        },
      ),
    );
  }

  /// 构建崩溃日志项
  Widget _buildCrashLogItem(CrashLogData crashLog) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: crashLog.isRead ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: crashLog.isRead 
              ? Colors.transparent 
              : crashLog.typeColor.withOpacity(0.3),
          width: crashLog.isRead ? 0 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: crashLog.typeColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: crashLog.typeColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                crashLog.typeIcon,
                color: crashLog.typeColor,
                size: 24,
              ),
            ),
            if (!crashLog.isRead)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          crashLog.typeDisplayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              crashLog.shortDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  crashLog.formattedTime,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                Icon(Icons.phone_android, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    crashLog.deviceModel,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'view':
                _viewCrashLogDetail(crashLog);
                break;
              case 'export_txt':
                _exportCrashLog(crashLog, 'txt');
                break;
              case 'export_json':
                _exportCrashLog(crashLog, 'json');
                break;
              case 'mark_read':
                _markAsRead(crashLog.id);
                break;
              case 'delete':
                _deleteCrashLog(crashLog.id);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: ListTile(
                leading: Icon(Icons.visibility),
                title: Text('查看详情'),
                dense: true,
              ),
            ),
            if (!crashLog.isRead)
              const PopupMenuItem(
                value: 'mark_read',
                child: ListTile(
                  leading: Icon(Icons.mark_email_read),
                  title: Text('标记为已读'),
                  dense: true,
                ),
              ),
            const PopupMenuItem(
              value: 'export_txt',
              child: ListTile(
                leading: Icon(Icons.text_snippet),
                title: Text('导出为文本'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'export_json',
              child: ListTile(
                leading: Icon(Icons.code),
                title: Text('导出为JSON'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('删除', style: TextStyle(color: Colors.red)),
                dense: true,
              ),
            ),
          ],
        ),
        onTap: () => _viewCrashLogDetail(crashLog),
      ),
    );
  }

  /// 查看崩溃日志详情
  void _viewCrashLogDetail(CrashLogData crashLog) {
    // 自动标记为已读
    if (!crashLog.isRead) {
      _markAsRead(crashLog.id);
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CrashLogDetailPage(crashLog: crashLog),
      ),
    );
  }
}

/// 崩溃日志详情页面
class CrashLogDetailPage extends StatefulWidget {
  final CrashLogData crashLog;

  const CrashLogDetailPage({Key? key, required this.crashLog}) : super(key: key);

  @override
  State<CrashLogDetailPage> createState() => _CrashLogDetailPageState();
}

class _CrashLogDetailPageState extends State<CrashLogDetailPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.crashLog.typeDisplayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareLog(context),
            tooltip: '分享日志',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () => _copyToClipboard(context),
            tooltip: '复制到剪贴板',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 基本信息卡片
            _buildInfoCard(
              title: '基本信息',
              icon: Icons.info,
              children: [
                _buildInfoRow('错误类型', widget.crashLog.typeDisplayName),
                _buildInfoRow('发生时间', widget.crashLog.formattedTime),
                _buildInfoRow('设备型号', widget.crashLog.deviceModel),
                _buildInfoRow('Android版本', widget.crashLog.androidVersion),
                _buildInfoRow('应用版本', widget.crashLog.appVersion),
              ],
            ),

            const SizedBox(height: 16),

            // 内存信息卡片
            _buildInfoCard(
              title: '内存信息',
              icon: Icons.memory,
              children: [
                _buildInfoRow('可用内存', '${(widget.crashLog.availableMemory / 1024 / 1024).toStringAsFixed(1)} MB'),
                _buildInfoRow('总内存', '${(widget.crashLog.totalMemory / 1024 / 1024).toStringAsFixed(1)} MB'),
                _buildInfoRow('内存使用率',
                  widget.crashLog.totalMemory > 0
                    ? '${((widget.crashLog.totalMemory - widget.crashLog.availableMemory) / widget.crashLog.totalMemory * 100).toStringAsFixed(1)}%'
                    : '未知'),
              ],
            ),

            const SizedBox(height: 16),

            // 错误信息卡片
            _buildInfoCard(
              title: '错误信息',
              icon: Icons.error,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    widget.crashLog.errorMessage.isNotEmpty ? widget.crashLog.errorMessage : '无错误信息',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 堆栈跟踪卡片
            _buildInfoCard(
              title: '堆栈跟踪',
              icon: Icons.list_alt,
              children: [
                Container(
                  width: double.infinity,
                  height: 300,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.crashLog.stackTrace.isNotEmpty ? widget.crashLog.stackTrace : '无堆栈信息',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 设备信息卡片
            _buildInfoCard(
              title: '设备详情',
              icon: Icons.phone_android,
              children: [
                Container(
                  width: double.infinity,
                  height: 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.crashLog.deviceInfo.isNotEmpty ? widget.crashLog.deviceInfo : '无设备信息',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 90),
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareLog(BuildContext context) {
    final String logText = '''
=== 崩溃日志详情 ===
时间: ${widget.crashLog.formattedTime}
类型: ${widget.crashLog.typeDisplayName}
设备: ${widget.crashLog.deviceModel}
Android: ${widget.crashLog.androidVersion}
应用版本: ${widget.crashLog.appVersion}

错误信息:
${widget.crashLog.errorMessage}

堆栈跟踪:
${widget.crashLog.stackTrace}

设备信息:
${widget.crashLog.deviceInfo}
''';

    Share.share(logText, subject: '崩溃日志 - ${widget.crashLog.typeDisplayName}');
  }

  void _copyToClipboard(BuildContext context) {
    final String logText = '''
时间: ${widget.crashLog.formattedTime}
类型: ${widget.crashLog.typeDisplayName}
错误: ${widget.crashLog.errorMessage}

${widget.crashLog.stackTrace}
''';

    Clipboard.setData(ClipboardData(text: logText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板')),
    );
  }
}
