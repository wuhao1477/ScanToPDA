import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

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

class BluetoothScannerPage extends StatefulWidget {
  const BluetoothScannerPage({Key? key}) : super(key: key);

  @override
  State<BluetoothScannerPage> createState() => _BluetoothScannerPageState();
}

class _BluetoothScannerPageState extends State<BluetoothScannerPage> with WidgetsBindingObserver {
  final List<BarcodeData> _scannedCodes = [];
  final ScrollController _scrollController = ScrollController();
  bool _isServiceRunning = false;
  bool _accessibilityServiceEnabled = false;
  String _lastError = '';
  bool _isPlatformSupported = false;
  
  // 控制面板展开状态
  bool _isServiceControlExpanded = true;
  bool _isFloatingWindowExpanded = false;
  bool _isAccessibilityExpanded = false;
  
  // 创建方法通道，用于控制后台服务
  static const MethodChannel _methodChannel = MethodChannel('com.example.scan_to_pda/barcode_scanner');

  // 创建事件通道，用于接收扫码结果
  static const EventChannel _eventChannel = EventChannel('com.example.scan_to_pda/barcode_scanner_events');
  
  StreamSubscription? _eventSubscription;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // 检查是否支持当前平台
    _isPlatformSupported = Platform.isAndroid;
    
    // 如果是Android平台，只检查无障碍服务状态，不自动启动服务
    if (_isPlatformSupported) {
      // 延迟一下，等界面完全加载后再检查状态
      Future.delayed(const Duration(milliseconds: 500), () {
        // 检查无障碍服务状态
        _checkAccessibilityServiceStatus();
      });
    } else {
      // 在不支持的平台上设置一个空的扫码记录，显示提示信息
      setState(() {
        _scannedCodes.add(BarcodeData(
          code: "此功能仅支持Android平台",
          timestamp: DateTime.now(),
        ));
      });
    }
  }

  @override
  void dispose() {
    // 确保事件订阅被正确取消
    _eventSubscription?.cancel();
    _eventSubscription = null;
    
    // 释放滚动控制器资源
    _scrollController.dispose();
    
    // 移除生命周期观察者
    WidgetsBinding.instance.removeObserver(this);
    
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('应用生命周期状态变化: $state');
    
    // 应用生命周期变化时处理
    if (state == AppLifecycleState.resumed) {
      // 恢复到前台时，先检查无障碍服务状态
      _checkAccessibilityServiceStatus();
      
      // 如果服务正在运行，则获取扫码记录并确保监听器正常工作
      if (_isServiceRunning) {
        _getScannedBarcodes();
        _listenForBarcodes(); // 重新设置监听器
        print('应用恢复前台，重新设置监听器');
      }
    } else if (state == AppLifecycleState.paused) {
      // 应用进入后台时的处理
      print('应用进入后台');
    }
  }

  // 启动后台服务
  Future<void> _startService() async {
    try {
      // 先检查无障碍服务是否已授权
      bool isAccessibilityEnabled = await _isAccessibilityServiceEnabled();
      
      if (!isAccessibilityEnabled) {
        // 如果无障碍服务未授权，展开无障碍服务面板
        setState(() {
          _isAccessibilityExpanded = true;
          _lastError = '请先授权无障碍服务，否则无法正常监听蓝牙扫码枪输入';
        });
        _showMessage('需要授权无障碍服务才能启动监听');
        return;
      }
      
      print("正在尝试启动蓝牙扫码服务..."); // 调试日志
      final bool result = await _methodChannel.invokeMethod('startService');
      print("服务启动结果: $result"); // 调试日志
      
      setState(() {
        _isServiceRunning = result;
        if (result) {
          _lastError = '';
          _showMessage('蓝牙扫码服务已启动');
          // 启动服务后设置监听
          _listenForBarcodes();
        } else {
          _lastError = '服务启动失败';
          _showMessage(_lastError);
        }
      });
    } on PlatformException catch (e) {
      print("服务启动异常: ${e.message}"); // 调试日志
      setState(() {
        _lastError = '启动服务失败: ${e.message}';
      });
      _showMessage(_lastError);
    } catch (e) {
      print("未知异常: $e"); // 调试日志
      setState(() {
        _lastError = '启动服务遇到未知错误: $e';
      });
      _showMessage(_lastError);
    }
  }
  
  // 停止后台服务
  Future<void> _stopService() async {
    try {
      final bool result = await _methodChannel.invokeMethod('stopService');
      setState(() {
        _isServiceRunning = !result;
        if (result) {
          _lastError = '';
          _showMessage('蓝牙扫码服务已停止');
        }
      });
    } on PlatformException catch (e) {
      setState(() {
        _lastError = '停止服务失败: ${e.message}';
      });
      _showMessage(_lastError);
    }
  }
  
  // 获取已扫描的条码
  Future<void> _getScannedBarcodes() async {
    try {
      final List<dynamic>? barcodes = await _methodChannel.invokeMethod('getScannedBarcodes');
      if (barcodes != null) {
        setState(() {
          _scannedCodes.clear();
          // 将原始条码转换为带时间戳的数据
          for (String code in barcodes.cast<String>()) {
            _scannedCodes.add(BarcodeData(
              code: code,
              timestamp: DateTime.now(), // 使用当前时间，因为无法获取原始时间戳
            ));
          }
        });
      }
    } on PlatformException catch (e) {
      setState(() {
        _lastError = '获取扫码记录失败: ${e.message}';
      });
      _showMessage(_lastError);
    }
  }
  
  // 显示/隐藏悬浮窗
  Future<void> _toggleFloatingWindow(bool show) async {
    try {
      final bool result = await _methodChannel.invokeMethod(
        show ? 'showFloatingWindow' : 'hideFloatingWindow'
      );
      
      if (result) {
        _showMessage(show ? '已显示悬浮窗' : '已隐藏悬浮窗');
      } else {
        _showMessage(show ? '显示悬浮窗失败' : '隐藏悬浮窗失败');
      }
    } catch (e) {
      _showMessage('控制悬浮窗失败: $e');
    }
  }
  
  // 申请悬浮窗权限
  Future<void> _requestOverlayPermission() async {
    try {
      final bool result = await _methodChannel.invokeMethod('requestOverlayPermission');
      if (!result) {
        _showMessage('需要授予悬浮窗权限才能在后台持续运行');
      }
    } catch (e) {
      _showMessage('请求悬浮窗权限失败: $e');
    }
  }
  
  // 检查无障碍服务是否启用
  Future<bool> _isAccessibilityServiceEnabled() async {
    try {
      final bool result = await _methodChannel.invokeMethod('isAccessibilityServiceEnabled');
      return result;
    } catch (e) {
      _showMessage('检查无障碍服务状态失败: $e');
      return false;
    }
  }
  
  // 请求无障碍服务权限
  Future<void> _requestAccessibilityPermission() async {
    try {
      await _methodChannel.invokeMethod('requestAccessibilityPermission');
    } catch (e) {
      _showMessage('请求无障碍服务权限失败: $e');
    }
  }
  
  // 清空扫描记录
  Future<void> _clearBarcodes() async {
    try {
      await _methodChannel.invokeMethod('clearBarcodes');
      setState(() {
        _scannedCodes.clear();
        _lastError = '';
      });
      _showMessage('已清空扫描记录');
    } on PlatformException catch (e) {
      setState(() {
        _lastError = '清空扫描记录失败: ${e.message}';
      });
      _showMessage(_lastError);
    }
  }
  
  // 监听扫码结果
  void _listenForBarcodes() {
    // 取消已有的订阅，避免重复监听
    _eventSubscription?.cancel();
    
    // 重新监听扫码事件
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen((dynamic event) {
      print('接收到事件通道数据: $event');
      
      if (event is String) {
        try {
          // 尝试解析JSON
          final Map<String, dynamic> jsonData = jsonDecode(event);
          print('JSON解析成功: $jsonData');
          
          final String code = jsonData['code'];
          final int timestamp = jsonData['timestamp'];
          
          setState(() {
            // 添加新的扫码记录
            _scannedCodes.insert(0, BarcodeData(
              code: code,
              timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
            ));
            print('已添加扫码记录到UI: $code');
          });
        } catch (e) {
          print('JSON解析失败: $e');
          
          // 如果解析失败，按照旧格式处理
          setState(() {
            _scannedCodes.insert(0, BarcodeData(
              code: event,
              timestamp: DateTime.now(),
            ));
            print('已添加原始数据到UI: $event');
          });
        }
      }
    }, onError: (dynamic error) {
      print('事件通道错误: $error');
      setState(() {
        _lastError = '监听扫码结果失败: $error';
      });
      _showMessage(_lastError);
    }, cancelOnError: false);
    
    print('已设置扫码事件监听器');
  }

  // 定期检查无障碍服务状态
  void _checkAccessibilityServiceStatus() async {
    bool isEnabled = await _isAccessibilityServiceEnabled();
    setState(() {
      _accessibilityServiceEnabled = isEnabled;
    });
    
    // 5秒后再次检查
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _checkAccessibilityServiceStatus();
      }
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // 构建服务控制面板
  Widget _buildServiceControlPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isServiceRunning ? null : _startService,
                icon: const Icon(Icons.play_arrow),
                label: const Text('启动监听服务'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isServiceRunning ? _stopService : null,
                icon: const Icon(Icons.stop),
                label: const Text('停止监听服务'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _isServiceRunning ? '监听服务已运行' : '监听服务未运行',
            style: TextStyle(
              color: _isServiceRunning ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // 构建悬浮窗控制面板
  Widget _buildFloatingWindowPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _toggleFloatingWindow(true),
                icon: const Icon(Icons.open_in_new),
                label: const Text('显示悬浮窗'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _toggleFloatingWindow(false),
                icon: const Icon(Icons.close),
                label: const Text('隐藏悬浮窗'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _requestOverlayPermission,
          icon: const Icon(Icons.admin_panel_settings),
          label: const Text('请求悬浮窗权限'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
          ),
        ),
      ],
    );
  }

  // 构建无障碍服务面板
  Widget _buildAccessibilityServicePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              _accessibilityServiceEnabled ? Icons.check_circle : Icons.error,
              color: _accessibilityServiceEnabled ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _accessibilityServiceEnabled
                    ? '无障碍服务已启用，可在后台接收蓝牙扫码枪输入'
                    : '无障碍服务未启用，必须先启用才能使用蓝牙扫码功能',
                style: TextStyle(
                  color: _accessibilityServiceEnabled ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        if (!_accessibilityServiceEnabled)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              '点击下方按钮，在系统设置中找到"蓝牙扫码枪服务"并启用它',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _requestAccessibilityPermission,
          icon: const Icon(Icons.settings_accessibility),
          label: const Text('打开无障碍服务设置'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
  
  // 自定义可折叠面板
  Widget _buildCustomExpansionPanel({
    required String title,
    required IconData icon,
    required Widget content,
    required bool isExpanded,
    required Function() onToggle,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          // 面板标题栏
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(icon, 
                    color: isExpanded ? Theme.of(context).primaryColor : Colors.grey[600],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isExpanded ? Theme.of(context).primaryColor : Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          
          // 可展开的内容区
          AnimatedCrossFade(
            firstChild: Container(),
            secondChild: Padding(
              padding: const EdgeInsets.all(16.0),
              child: content,
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 主内容区域
        Expanded(
          child: _isPlatformSupported
            ? Column(
            children: [
              // 说明文本
              Container(
                margin: const EdgeInsets.all(12.0),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.blue.withOpacity(0.2), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue[600],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '请使用下方控制面板手动启动服务并授予必要权限，启动后才能监听蓝牙扫码枪输入',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 自定义折叠面板区域
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  children: [
                    _buildCustomExpansionPanel(
                      title: '服务控制',
                      icon: Icons.play_circle_outlined,
                      content: _buildServiceControlPanel(),
                      isExpanded: _isServiceControlExpanded,
                      onToggle: () {
                        setState(() {
                          _isServiceControlExpanded = !_isServiceControlExpanded;
                        });
                      },
                    ),
                    _buildCustomExpansionPanel(
                      title: '悬浮窗控制',
                      icon: Icons.open_in_new,
                      content: _buildFloatingWindowPanel(),
                      isExpanded: _isFloatingWindowExpanded,
                      onToggle: () {
                        setState(() {
                          _isFloatingWindowExpanded = !_isFloatingWindowExpanded;
                        });
                      },
                    ),
                    _buildCustomExpansionPanel(
                      title: '无障碍服务',
                      icon: Icons.settings_accessibility,
                      content: _buildAccessibilityServicePanel(),
                      isExpanded: _isAccessibilityExpanded,
                      onToggle: () {
                        setState(() {
                          _isAccessibilityExpanded = !_isAccessibilityExpanded;
                        });
                      },
                    ),
                  ],
                ),
              ),
              
              // 错误信息
              if (_lastError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    _lastError,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                              ),
              
              // 分割线
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                height: 1,
                color: Colors.grey.withOpacity(0.3),
              ),
              
              // 扫描记录标题
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.list_alt, 
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '扫码记录 (${_scannedCodes.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    // {{ AURA-X: Add - 将刷新和清理按钮集成到标题行右侧. Approval: 寸止(ID:1735728401). }}
                    if (_isPlatformSupported) ...[
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: _getScannedBarcodes,
                        tooltip: '刷新扫描记录',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: _clearBarcodes,
                        tooltip: '清空扫描记录',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // 扫描记录列表
              Expanded(
                child: _scannedCodes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.qr_code_scanner, 
                                size: 64, 
                                color: Colors.blue.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '还没有扫描记录',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '启动监听服务后，扫码记录将显示在这里',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _scannedCodes.length,
                        itemBuilder: (context, index) {
                          final barcodeData = _scannedCodes[index];
                          final time = barcodeData.timestamp;
                          final formattedTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: ListTile(
                              leading: const Icon(Icons.qr_code, color: Colors.blue),
                              title: Text('扫码结果 #${index + 1}'),
                              subtitle: Text(
                                barcodeData.code,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: Text(
                                formattedTime,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          )
        : Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.android_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '此功能需要Android设备上的无障碍服务支持',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '请在Android设备上运行此应用以使用完整功能',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),  // {{ AURA-X: Add - 关闭最外层Expanded组件的右括号. Approval: 寸止(ID:1735728400). }}
      ],
    );
  }
} 