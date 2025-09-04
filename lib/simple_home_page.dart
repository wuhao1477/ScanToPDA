import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'permission_guide_page.dart';
import 'settings_page.dart';

class BarcodeData {
  final String code;
  final DateTime timestamp;

  BarcodeData({
    required this.code,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'BarcodeData{code: $code, timestamp: $timestamp}';
  }
}

class SimpleHomePage extends StatefulWidget {
  const SimpleHomePage({super.key});

  @override
  State<SimpleHomePage> createState() => _SimpleHomePageState();
}

class _SimpleHomePageState extends State<SimpleHomePage> {
  final List<BarcodeData> _scannedCodes = [];
  final ScrollController _scrollController = ScrollController();
  
  // 服务状态
  bool _isServiceRunning = false;
  bool _isFloatingWindowRunning = false;
  
  // 权限状态
  Map<String, bool> _permissions = {
    'bluetooth': false,
    'accessibility': false,
    'overlay': false,
  };
  
  bool _allRequiredPermissionsGranted = false;
  bool _isLoading = true;
  String _lastError = '';
  
  // 方法通道
  static const MethodChannel _methodChannel = MethodChannel('com.example.scan_to_pda/barcode_scanner');
  static const EventChannel _eventChannel = EventChannel('com.example.scan_to_pda/barcode_scanner_events');
  
  StreamSubscription? _eventSubscription;
  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  // 初始化应用
  Future<void> _initializeApp() async {
    await _checkPermissions();
    if (_allRequiredPermissionsGranted) {
      _setupEventListener();
      _startStatusCheck();
    }
  }

  // 检查权限状态
  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);
    
    try {
      final bluetoothPermission = await _methodChannel.invokeMethod('hasBluetoothPermissions');
      final accessibilityEnabled = await _methodChannel.invokeMethod('isAccessibilityServiceEnabled');
      final deviceInfo = await _methodChannel.invokeMethod('getDeviceCompatibility');
      
      setState(() {
        _permissions = {
          'bluetooth': bluetoothPermission,
          'accessibility': accessibilityEnabled,
          'overlay': deviceInfo['hasOverlayPermission'] ?? false,
        };
        _allRequiredPermissionsGranted = _permissions['bluetooth']! && _permissions['accessibility']!;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _lastError = '检查权限失败: $e';
        _isLoading = false;
      });
    }
  }

  // 设置事件监听器
  void _setupEventListener() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          _handleKeyEvent(event);
        }
      },
      onError: (error) {
        setState(() => _lastError = '事件监听错误: $error');
      },
    );
  }

  // 处理按键事件
  void _handleKeyEvent(Map<dynamic, dynamic> event) {
    try {
      final keyCode = event['keyCode'] as int?;
      final characters = event['characters'] as String?;
      
      if (characters != null && characters.isNotEmpty && characters != '\n') {
        final newBarcode = BarcodeData(
          code: characters,
          timestamp: DateTime.now(),
        );
        
        setState(() {
          _scannedCodes.insert(0, newBarcode);
          if (_scannedCodes.length > 1000) {
            _scannedCodes.removeRange(1000, _scannedCodes.length);
          }
        });
        
        // 自动滚动到顶部
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    } catch (e) {
      print('处理按键事件失败: $e');
    }
  }

  // 启动状态检查定时器
  void _startStatusCheck() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkServiceStatus();
    });
    _checkServiceStatus(); // 立即检查一次
  }

  // 检查服务状态
  Future<void> _checkServiceStatus() async {
    try {
      // 这里可以添加检查服务状态的逻辑
      // 暂时保持当前状态
    } catch (e) {
      print('检查服务状态失败: $e');
    }
  }

  // 启动扫码服务
  Future<void> _startService() async {
    if (!_allRequiredPermissionsGranted) {
      _showMessage('请先完成权限设置');
      return;
    }

    try {
      setState(() => _lastError = '');
      print('正在尝试启动蓝牙扫码服务...');
      
      final bool result = await _methodChannel.invokeMethod('startService');
      print('服务启动结果: $result');
      
      if (result) {
        setState(() => _isServiceRunning = true);
        _showMessage('扫码服务已启动');
        print('已设置扫码事件监听器');
      } else {
        _showMessage('服务启动失败');
      }
    } catch (e) {
      setState(() => _lastError = '启动服务失败: $e');
      _showMessage('启动失败: $e');
    }
  }

  // 停止扫码服务
  Future<void> _stopService() async {
    try {
      final bool result = await _methodChannel.invokeMethod('stopService');
      if (result) {
        setState(() => _isServiceRunning = false);
        _showMessage('扫码服务已停止');
      }
    } catch (e) {
      setState(() => _lastError = '停止服务失败: $e');
    }
  }

  // 启动悬浮窗
  Future<void> _startFloatingWindow() async {
    if (!_permissions['overlay']!) {
      _showMessage('请先授予悬浮窗权限');
      return;
    }

    try {
      await _methodChannel.invokeMethod('startFloatingWindow');
      setState(() => _isFloatingWindowRunning = true);
      _showMessage('悬浮窗已启动');
    } catch (e) {
      _showMessage('启动悬浮窗失败: $e');
    }
  }

  // 停止悬浮窗
  Future<void> _stopFloatingWindow() async {
    try {
      await _methodChannel.invokeMethod('stopFloatingWindow');
      setState(() => _isFloatingWindowRunning = false);
      _showMessage('悬浮窗已停止');
    } catch (e) {
      _showMessage('停止悬浮窗失败: $e');
    }
  }

  // 清除扫码记录
  void _clearScannedCodes() {
    setState(() => _scannedCodes.clear());
    _showMessage('已清除所有扫码记录');
  }

  // 显示消息
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 打开权限设置页面
  Future<void> _openPermissionGuide() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const PermissionGuidePage()),
    );
    
    if (result == true) {
      await _checkPermissions();
      if (_allRequiredPermissionsGranted) {
        _setupEventListener();
        _startStatusCheck();
        _showMessage('权限设置完成！');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('扫码助手'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在初始化...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('扫码助手'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            ),
            tooltip: '设置',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkPermissions,
            tooltip: '刷新状态',
          ),
        ],
      ),
      body: _allRequiredPermissionsGranted 
          ? _buildMainContent()
          : _buildPermissionPrompt(),
    );
  }

  Widget _buildPermissionPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.security,
              size: 64,
              color: Colors.orange.shade600,
            ),
            const SizedBox(height: 24),
            const Text(
              '需要设置权限',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '应用需要蓝牙和无障碍权限才能正常工作\n请点击下方按钮完成权限设置',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openPermissionGuide,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('前往权限设置'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // 服务控制面板
        _buildServiceControlPanel(),
        
        // 错误信息显示
        if (_lastError.isNotEmpty) _buildErrorMessage(),
        
        // 扫码记录
        Expanded(child: _buildScanRecords()),
      ],
    );
  }

  Widget _buildServiceControlPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // 主服务开关
          Row(
            children: [
              Icon(
                _isServiceRunning ? Icons.play_circle : Icons.stop_circle,
                color: _isServiceRunning ? Colors.green : Colors.grey,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '扫码服务',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _isServiceRunning ? '运行中' : '已停止',
                      style: TextStyle(
                        color: _isServiceRunning ? Colors.green : Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isServiceRunning,
                onChanged: (value) {
                  if (value) {
                    _startService();
                  } else {
                    _stopService();
                  }
                },
              ),
            ],
          ),
          
          const Divider(height: 32),
          
          // 悬浮窗开关
          Row(
            children: [
              Icon(
                _isFloatingWindowRunning ? Icons.picture_in_picture : Icons.picture_in_picture_outlined,
                color: _isFloatingWindowRunning ? Colors.blue : Colors.grey,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '悬浮窗',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _isFloatingWindowRunning ? '显示中' : '已隐藏',
                      style: TextStyle(
                        color: _isFloatingWindowRunning ? Colors.blue : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isFloatingWindowRunning,
                onChanged: _permissions['overlay']! ? (value) {
                  if (value) {
                    _startFloatingWindow();
                  } else {
                    _stopFloatingWindow();
                  }
                } : null,
              ),
            ],
          ),
          
          if (!_permissions['overlay']!)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '需要悬浮窗权限',
                style: TextStyle(color: Colors.orange.shade600, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _lastError,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _lastError = ''),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildScanRecords() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '扫码记录',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${_scannedCodes.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear_all),
                  onPressed: _scannedCodes.isNotEmpty ? _clearScannedCodes : null,
                  tooltip: '清除记录',
                ),
              ],
            ),
          ),
          
          // 记录列表
          Expanded(
            child: _scannedCodes.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('暂无扫码记录', style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 8),
                        Text(
                          '启动服务后，扫码枪扫描的内容将显示在这里',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _scannedCodes.length,
                    itemBuilder: (context, index) {
                      final barcode = _scannedCodes[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            barcode.code,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                          subtitle: Text(
                            '${barcode.timestamp.hour.toString().padLeft(2, '0')}:'
                            '${barcode.timestamp.minute.toString().padLeft(2, '0')}:'
                            '${barcode.timestamp.second.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: barcode.code));
                              _showMessage('已复制到剪贴板');
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
