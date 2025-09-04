import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class BroadcastModel {
  final String action;
  final Map<String, dynamic> extras;
  final DateTime timestamp;
  final bool isPdaScan;

  BroadcastModel({
    required this.action,
    required this.extras,
    required this.timestamp,
    this.isPdaScan = false,
  });

  @override
  String toString() {
    return 'Action: $action\nExtras: $extras\nTime: ${timestamp.hour}:${timestamp.minute}:${timestamp.second}';
  }
}

class BroadcastReceiverPage extends StatefulWidget {
  const BroadcastReceiverPage({Key? key}) : super(key: key);

  @override
  State<BroadcastReceiverPage> createState() => _BroadcastReceiverPageState();
}

class _BroadcastReceiverPageState extends State<BroadcastReceiverPage> {
  final List<BroadcastModel> _broadcasts = [];
  bool _isListening = false;
  String _filterKeyword = '';
  final TextEditingController _filterController = TextEditingController();
  bool _onlyShowPdaScan = false;

  // 定义Method Channel
  static const platform = MethodChannel('com.scan_to_pda.broadcast_receiver');
  static const broadcastEventChannel = EventChannel('com.scan_to_pda.broadcast_receiver/events');
  StreamSubscription? _broadcastSubscription;

  // PDA 扫码枪常见的广播 Action 列表
  final List<String> _pdaScanActions = [
    'android.intent.action.DECODE_DATA',
    'com.android.server.scannerservice.broadcast',
    'android.intent.ACTION_DECODE_DATA',
    'scanner.rcv.message',
    'com.symbol.datawedge.api.RESULT_ACTION',
    'com.honeywell.intent.action.SCAN_RESULT',
    'unitech.scanservice.result',
  ];

  @override
  void initState() {
    super.initState();
    // 监听广播事件
    _setupBroadcastListener();
  }

  // 设置广播事件监听
  void _setupBroadcastListener() {
    broadcastEventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        _handleBroadcastEvent(Map<String, dynamic>.from(event));
      }
    }, onError: (dynamic error) {
      _showMessage('广播监听错误: $error');
    });
  }

  // 处理广播事件
  void _handleBroadcastEvent(Map<String, dynamic> event) {
    final action = event['action'] as String? ?? 'Unknown';
    final extras = Map<String, dynamic>.from(event['extras'] as Map? ?? {});
    
    // 判断是否为PDA扫码枪广播
    bool isPdaScan = _isPdaScanBroadcast(action, extras);

    // 创建广播数据模型
    final broadcast = BroadcastModel(
      action: action,
      extras: extras,
      timestamp: DateTime.now(),
      isPdaScan: isPdaScan,
    );

    setState(() {
      _broadcasts.insert(0, broadcast); // 新的广播放在最上面
    });
  }

  // 初始化广播接收器
  Future<void> _startListening() async {
    if (_isListening) return;

    try {
      // 调用原生方法注册广播接收器
      final result = await platform.invokeMethod('startBroadcastReceiver');
      
      if (result == true) {
        setState(() {
          _isListening = true;
        });
        _showMessage('开始监听广播');
      } else {
        _showMessage('启动广播监听失败');
      }
    } catch (e) {
      _showMessage('启动广播监听失败: $e');
    }
  }

  // 检查是否为PDA扫码枪广播
  bool _isPdaScanBroadcast(String action, Map<String, dynamic> extras) {
    // 根据Action判断
    if (_pdaScanActions.any((a) => action.contains(a))) {
      return true;
    }

    // 根据广播内容判断，检查extras中是否包含barcode, scanData等扫码相关内容
    final keysToCheck = ['barcode', 'scandata', 'scan_data', 'data', 'barcodeData'];
    for (var key in extras.keys) {
      if (keysToCheck.any((k) => key.toLowerCase().contains(k.toLowerCase()))) {
        return true;
      }
    }

    return false;
  }

  // 停止监听广播
  Future<void> _stopListening() async {
    try {
      // 调用原生方法注销广播接收器
      final result = await platform.invokeMethod('stopBroadcastReceiver');
      
      if (result == true) {
        setState(() {
          _isListening = false;
        });
        _showMessage('已停止监听广播');
      } else {
        _showMessage('停止广播监听失败');
      }
    } catch (e) {
      _showMessage('停止广播监听失败: $e');
    }
  }

  // 清空广播记录
  void _clearBroadcasts() {
    setState(() {
      _broadcasts.clear();
    });
  }

  // 过滤广播
  List<BroadcastModel> _getFilteredBroadcasts() {
    if (_filterKeyword.isEmpty && !_onlyShowPdaScan) {
      return _broadcasts;
    }

    return _broadcasts.where((broadcast) {
      // 如果只显示PDA扫码枪广播
      if (_onlyShowPdaScan && !broadcast.isPdaScan) {
        return false;
      }

      // 根据关键字过滤
      if (_filterKeyword.isNotEmpty) {
        final keyword = _filterKeyword.toLowerCase();
        return broadcast.action.toLowerCase().contains(keyword) ||
            broadcast.extras.toString().toLowerCase().contains(keyword);
      }

      return true;
    }).toList();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _stopListening();
    _filterController.dispose();
    _broadcastSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredBroadcasts = _getFilteredBroadcasts();

    return Scaffold(
      appBar: AppBar(
        title: const Text('广播监听器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _broadcasts.isEmpty ? null : _clearBroadcasts,
            tooltip: '清空记录',
          ),
        ],
      ),
      body: Column(
        children: [
          // 控制面板
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isListening ? null : _startListening,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text('开始监听'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isListening ? _stopListening : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('停止监听'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _filterController,
                      decoration: const InputDecoration(
                        labelText: '按关键字筛选',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _filterKeyword = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('仅显示PDA扫码广播'),
                      value: _onlyShowPdaScan,
                      onChanged: (value) {
                        setState(() {
                          _onlyShowPdaScan = value;
                        });
                      },
                    ),
                    Text(
                      '已接收 ${_broadcasts.length} 条广播，当前显示 ${filteredBroadcasts.length} 条',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 广播列表
          Expanded(
            child: filteredBroadcasts.isEmpty
                ? Center(
                    child: Text(
                      _isListening ? '等待接收广播...' : '点击"开始监听"按钮开始接收广播',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredBroadcasts.length,
                    itemBuilder: (context, index) {
                      final broadcast = filteredBroadcasts[index];
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: broadcast.isPdaScan ? Colors.yellow.shade100 : null,
                        child: ExpansionTile(
                          leading: Icon(
                            broadcast.isPdaScan ? Icons.qr_code_scanner : Icons.broadcast_on_personal,
                            color: broadcast.isPdaScan ? Colors.orange : Colors.blue,
                          ),
                          title: Text(
                            broadcast.action,
                            style: TextStyle(
                              fontWeight: broadcast.isPdaScan ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            '${broadcast.timestamp.hour}:${broadcast.timestamp.minute}:${broadcast.timestamp.second}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Extra 数据:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  ...broadcast.extras.entries.map((entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Text('${entry.key}: ${entry.value}'),
                                  )).toList(),
                                ],
                              ),
                            ),
                          ],
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