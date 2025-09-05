import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PermissionGuidePage extends StatefulWidget {
  const PermissionGuidePage({
    super.key,
    this.autoExit = false, // 默认不自动退出，允许用户主动查看
  });

  final bool autoExit;

  @override
  State<PermissionGuidePage> createState() => _PermissionGuidePageState();
}

class _PermissionGuidePageState extends State<PermissionGuidePage> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.scan_to_pda/barcode_scanner');
  
  // 权限状态
  Map<String, bool> _permissions = {
    'bluetooth': false,
    'location': false,
    'overlay': false,
    'accessibility': false,
  };

  // 设备兼容性信息
  Map<String, dynamic> _deviceInfo = {};


  bool _isLoading = true;
  bool _allPermissionsGranted = false;

  @override
  void initState() {
    super.initState();
    // 添加生命周期观察者
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }


  @override
  void dispose() {
    // 移除生命周期观察者
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 当应用从后台恢复到前台时，自动刷新权限状态
    if (state == AppLifecycleState.resumed) {
      print('权限向导页面：应用恢复前台，刷新权限状态');
      _checkAllPermissions();
    }
  }


  // 检查所有权限状态
  Future<void> _checkAllPermissions() async {
    setState(() => _isLoading = true);
    
    try {
      // 获取设备兼容性信息
      final deviceInfo = await platform.invokeMethod('getDeviceCompatibility');
      
      // 检查各项权限
      final bluetoothPermission = await platform.invokeMethod('hasBluetoothPermissions');
      final accessibilityEnabled = await platform.invokeMethod('isAccessibilityServiceEnabled');
      
      setState(() {
        _deviceInfo = Map<String, dynamic>.from(deviceInfo);
        _permissions = {
          'bluetooth': bluetoothPermission,
          'location': _deviceInfo['hasLocationPermission'] ?? false,
          'overlay': _deviceInfo['hasOverlayPermission'] ?? false,
          'accessibility': accessibilityEnabled,
        };
        // 只检查必需权限（蓝牙和无障碍），悬浮窗是可选的
        _allPermissionsGranted = _permissions['bluetooth']! && _permissions['accessibility']!;
        _isLoading = false;

        // 如果设置了自动退出且所有必需权限都已授权，自动退出页面并启动服务
        if (widget.autoExit && _allPermissionsGranted && mounted) {
          print('权限向导页面：检测到所有必需权限已授权，自动退出并启动服务');
          Navigator.of(context).pop('auto_start_service');
        }
      });
    } catch (e) {
      print('检查权限失败: $e');
      setState(() => _isLoading = false);
    }
  }

  // 请求蓝牙权限
  Future<void> _requestBluetoothPermission() async {
    try {
      await platform.invokeMethod('requestBluetoothPermissions');
      await Future.delayed(const Duration(seconds: 1));
      await _checkAllPermissions();
    } catch (e) {
      _showError('请求蓝牙权限失败: $e');
    }
  }

  // 请求位置权限
  Future<void> _requestLocationPermission() async {
    try {
      await platform.invokeMethod('requestLocationPermissions');
      await Future.delayed(const Duration(seconds: 1));
      await _checkAllPermissions();
    } catch (e) {
      _showError('请求位置权限失败: $e');
    }
  }

  // 请求悬浮窗权限
  Future<void> _requestOverlayPermission() async {
    try {
      await platform.invokeMethod('requestOverlayPermission');
      await Future.delayed(const Duration(seconds: 2));
      await _checkAllPermissions();
    } catch (e) {
      _showError('请求悬浮窗权限失败: $e');
    }
  }

  // 请求无障碍权限
  Future<void> _requestAccessibilityPermission() async {
    try {
      await platform.invokeMethod('requestAccessibilityPermission');
      await Future.delayed(const Duration(seconds: 2));
      await _checkAllPermissions();
    } catch (e) {
      _showError('请求无障碍权限失败: $e');
    }
  }

  // 显示错误消息
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('权限设置向导'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkAllPermissions,
            tooltip: '刷新权限状态',
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingView() : _buildPermissionView(),
      floatingActionButton: _allPermissionsGranted
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).pop('manual_complete'),
              icon: const Icon(Icons.check_circle),
              label: const Text('完成设置'),
              backgroundColor: Colors.green,
            )
          : null,
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('正在检查权限状态...'),
        ],
      ),
    );
  }

  Widget _buildPermissionView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 设备信息卡片
          _buildDeviceInfoCard(),
          const SizedBox(height: 16),
          
          // 权限状态总览
          _buildPermissionOverview(),
          const SizedBox(height: 16),
          
          // 权限详细设置
          _buildPermissionDetails(),
          
          // 底部说明
          const SizedBox(height: 32),
          _buildBottomNote(),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_android, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text('设备信息', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Android版本', 'API ${_deviceInfo['apiLevel'] ?? '未知'}'),
            _buildInfoRow('蓝牙权限类型', _deviceInfo['bluetoothPermissionType'] ?? '未知'),
            _buildInfoRow('运行时权限', _deviceInfo['supportsRuntimePermissions'] == true ? '支持' : '不支持'),
            if (_deviceInfo['needsLocationForBluetooth'] == true)
              _buildInfoRow('蓝牙扫描', '需要位置权限'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionOverview() {
    // 只统计必需权限
    final requiredPermissions = ['bluetooth', 'accessibility'];
    if (_deviceInfo['needsLocationForBluetooth'] == true) {
      requiredPermissions.add('location');
    }
    
    final grantedRequiredCount = requiredPermissions.where((key) => _permissions[key] == true).length;
    final totalRequiredCount = requiredPermissions.length;
    
    return Card(
      color: _allPermissionsGranted ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _allPermissionsGranted ? Icons.check_circle : Icons.warning,
              color: _allPermissionsGranted ? Colors.green : Colors.orange,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _allPermissionsGranted ? '权限设置完成' : '需要设置权限',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _allPermissionsGranted ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '必需权限: $grantedRequiredCount/$totalRequiredCount 项已授权',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '权限详细设置',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        // 蓝牙权限
        _buildPermissionCard(
          title: '蓝牙权限',
          description: '用于连接和扫描蓝牙扫码枪设备',
          icon: Icons.bluetooth,
          isGranted: _permissions['bluetooth']!,
          onRequest: _requestBluetoothPermission,
          isRequired: true,
        ),
        
        // 位置权限（仅在需要时显示）
        if (_deviceInfo['needsLocationForBluetooth'] == true)
          _buildPermissionCard(
            title: '位置权限',
            description: '在Android 6.0-11版本中，蓝牙扫描需要位置权限',
            icon: Icons.location_on,
            isGranted: _permissions['location']!,
            onRequest: _requestLocationPermission,
            isRequired: true,
          ),

        // 无障碍权限
        _buildPermissionCard(
          title: '无障碍服务',
          description: '用于监听键盘输入和自动化操作',
          icon: Icons.accessibility,
          isGranted: _permissions['accessibility']!,
          onRequest: _requestAccessibilityPermission,
          isRequired: true,
        ),
        
        // 悬浮窗权限（可选）
        _buildPermissionCard(
          title: '悬浮窗权限',
          description: '允许应用在其他应用上方显示悬浮窗口（可选功能）',
          icon: Icons.picture_in_picture,
          isGranted: _permissions['overlay']!,
          onRequest: _requestOverlayPermission,
          isRequired: false,
        ),
      ],
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isGranted,
    required VoidCallback onRequest,
    required bool isRequired,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isGranted ? Colors.green.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                color: isGranted ? Colors.green.shade700 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isRequired ? Colors.red.shade100 : Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isRequired ? '必需' : '可选',
                          style: TextStyle(
                            fontSize: 10,
                            color: isRequired ? Colors.red.shade700 : Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              children: [
                Icon(
                  isGranted ? Icons.check_circle : Icons.cancel,
                  color: isGranted ? Colors.green : Colors.red,
                ),
                const SizedBox(height: 8),
                if (!isGranted)
                  ElevatedButton(
                    onPressed: onRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text('授权', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                '使用说明',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• 蓝牙权限：必需，用于连接扫码枪设备\n'
            '• 位置权限：在Android 6.0-11版本中蓝牙扫描需要此权限\n'
            '• 悬浮窗权限：可选，允许显示悬浮状态窗口\n'
            '• 无障碍服务：必需，用于监听键盘输入事件\n\n'
            '完成必需权限授权后，点击右下角"完成设置"进入主界面。\n'
            '悬浮窗权限可稍后在需要时再授权。',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }
}
