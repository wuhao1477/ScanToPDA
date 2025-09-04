import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '蓝牙扫码枪监听',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BluetoothScannerPage(),
    );
  }
}

class BluetoothScannerPage extends StatefulWidget {
  const BluetoothScannerPage({Key? key}) : super(key: key);

  @override
  State<BluetoothScannerPage> createState() => _BluetoothScannerPageState();
}

class _BluetoothScannerPageState extends State<BluetoothScannerPage> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  String _lastScannedData = '';
  BluetoothDevice? _connectedDevice;
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // 请求蓝牙和位置权限
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (status != PermissionStatus.granted) {
        allGranted = false;
      }
    });

    if (allGranted) {
      _initBluetooth();
    } else {
      _showMessage('请授予蓝牙和位置权限以使用此应用');
    }
  }

  Future<void> _initBluetooth() async {
    // 监听蓝牙状态
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        _startScan();
      }
    });

    // 监听扫描结果
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _scanResults = results;
      });
    });

    // 监听扫描状态
    FlutterBluePlus.isScanning.listen((isScanning) {
      setState(() {
        _isScanning = isScanning;
      });
    });

    // 检查蓝牙是否开启
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState == BluetoothAdapterState.on) {
      _startScan();
    } else {
      _showMessage('请打开蓝牙');
    }
  }

  Future<void> _startScan() async {
    try {
      // 开始扫描
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );
    } catch (e) {
      _showMessage('扫描错误: $e');
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      _showMessage('正在连接到: ${device.platformName}...');

      // 连接到设备
      await device.connect();
      _connectedDevice = device;
      _showMessage('已连接到: ${device.platformName}');

      // 监听连接状态
      device.connectionState.listen((state) {
        setState(() {
          _connectionState = state;
        });

        if (state == BluetoothConnectionState.disconnected) {
          _showMessage('设备已断开连接');
          setState(() {
            _connectedDevice = null;
          });
        }
      });

      // 发现服务
      _showMessage('正在搜索服务...');
      List<BluetoothService> services = await device.discoverServices();

      // 寻找合适的服务和特征
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          // 检查特征是否可通知
          if (characteristic.properties.notify) {
            // 订阅通知
            await characteristic.setNotifyValue(true);
            _showMessage('已订阅数据通知');

            // 监听数据
            characteristic.onValueReceived.listen((value) {
              String receivedData = String.fromCharCodes(value);
              setState(() {
                _lastScannedData = receivedData;
              });
              _showMessage('收到数据: $receivedData');
            });
          }
        }
      }
    } catch (e) {
      _showMessage('连接失败: $e');
    }
  }

  Future<void> _disconnectDevice() async {
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
        setState(() {
          _connectedDevice = null;
        });
        _showMessage('已断开连接');
      } catch (e) {
        _showMessage('断开连接失败: $e');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('蓝牙扫码枪监听'),
        actions: [
          if (_connectedDevice != null)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled),
              onPressed: _disconnectDevice,
              tooltip: '断开连接',
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '最近扫描结果: $_lastScannedData',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          if (_connectedDevice != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                color: Colors.blue.shade100,
                child: ListTile(
                  leading: const Icon(Icons.bluetooth_connected),
                  title: Text('已连接: ${_connectedDevice!.platformName}'),
                  subtitle: Text('状态: ${_connectionState.toString().split('.').last}'),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _scanResults.length,
              itemBuilder: (context, index) {
                final result = _scanResults[index];
                final device = result.device;
                final String deviceName = device.platformName.isNotEmpty
                    ? device.platformName
                    : '未知设备';

                return ListTile(
                  title: Text(deviceName),
                  subtitle: Text(device.remoteId.str),
                  trailing: ElevatedButton(
                    onPressed: device.remoteId.str == _connectedDevice?.remoteId.str
                        ? null
                        : () => _connectToDevice(device),
                    child: Text(
                        device.remoteId.str == _connectedDevice?.remoteId.str
                            ? '已连接'
                            : '连接'
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_isScanning) {
            FlutterBluePlus.stopScan();
          } else {
            _startScan();
          }
        },
        child: Icon(_isScanning ? Icons.stop : Icons.search),
      ),
    );
  }

  @override
  void dispose() {
    // 确保停止扫描
    FlutterBluePlus.stopScan();
    // 断开连接
    if (_connectedDevice != null) {
      _connectedDevice!.disconnect();
    }
    super.dispose();
  }
}