import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class EasterEggSettingsPage extends StatefulWidget {
  const EasterEggSettingsPage({Key? key}) : super(key: key);

  @override
  State<EasterEggSettingsPage> createState() => _EasterEggSettingsPageState();
}

class _EasterEggSettingsPageState extends State<EasterEggSettingsPage> {
  // 后置操作类型
  String _actionType = 'none'; // none, app, url
  String _targetPackage = '';
  String _targetUrl = '';
  String _selectedAppName = '';
  

  @override
  void initState() {
    super.initState();
    _loadEnvironmentDefaults();
    _loadSettings();
  }
  
  // 加载环境变量默认配置
  void _loadEnvironmentDefaults() {
    // 这些值在构建时会被环境变量替换
    const String envActionType = String.fromEnvironment('EASTER_EGG_ACTION_TYPE', defaultValue: 'none');
    const String envTargetPackage = String.fromEnvironment('EASTER_EGG_TARGET_PACKAGE', defaultValue: '');
    const String envTargetUrl = String.fromEnvironment('EASTER_EGG_TARGET_URL', defaultValue: '');
    const String envSelectedAppName = String.fromEnvironment('EASTER_EGG_SELECTED_APP_NAME', defaultValue: '');
    
    // 如果环境变量中有配置，则使用环境变量的值作为默认值
    if (envActionType != 'none' || envTargetPackage.isNotEmpty || envTargetUrl.isNotEmpty) {
      _actionType = envActionType;
      _targetPackage = envTargetPackage;
      _targetUrl = envTargetUrl;
      _selectedAppName = envSelectedAppName;
      
      print('彩蛋功能：使用环境变量配置 - 类型: $envActionType, 包名: $envTargetPackage, 网址: $envTargetUrl');
    }
  }

  // 加载设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 用户设置优先，如果没有用户设置则保持环境变量的默认值
      setState(() {
        _actionType = prefs.getString('easter_egg_action_type') ?? _actionType;
        _targetPackage = prefs.getString('easter_egg_target_package') ?? _targetPackage;
        _targetUrl = prefs.getString('easter_egg_target_url') ?? _targetUrl;
        _selectedAppName = prefs.getString('easter_egg_selected_app_name') ?? _selectedAppName;
      });
    } catch (e) {
      print('加载彩蛋设置失败: $e');
    }
  }

  // 保存设置
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('easter_egg_action_type', _actionType);
      await prefs.setString('easter_egg_target_package', _targetPackage);
      await prefs.setString('easter_egg_target_url', _targetUrl);
      await prefs.setString('easter_egg_selected_app_name', _selectedAppName);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('设置已保存'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 根据包名获取应用显示名称
  String _getAppDisplayName(String packageName) {
    // 根据常见应用包名返回友好的显示名称
    switch (packageName) {
      case 'com.tencent.mm':
        return '微信';
      case 'com.tencent.mobileqq':
        return 'QQ';
      case 'com.eg.android.AlipayGphone':
        return '支付宝';
      case 'com.taobao.taobao':
        return '淘宝';
      case 'com.ss.android.ugc.aweme':
        return '抖音';
      case 'com.android.chrome':
        return 'Chrome浏览器';
      default:
        return '自定义应用';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.egg, color: Colors.orange),
            SizedBox(width: 8),
            Text('彩蛋设置'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: '保存设置',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 功能说明卡片
            _buildDescriptionCard(),
            const SizedBox(height: 16),
            
            // 操作类型选择
            _buildActionTypeSection(),
            const SizedBox(height: 16),
            
            // 根据选择的类型显示相应的配置界面
            if (_actionType == 'app') _buildAppSelectionSection(),
            if (_actionType == 'url') _buildUrlConfigSection(),
            
            const SizedBox(height: 24),
            
            // 测试按钮
            _buildTestSection(),
            
            const SizedBox(height: 24),
            
            // 环境变量说明
            _buildEnvironmentVariableSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  '后置操作配置',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '配置扫码成功后的自动操作。可以设置为打开指定应用或访问特定网址。\n\n'
              '注意：这是一个隐藏功能，主要用于特定场景的自动化需求。',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTypeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '操作类型',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            RadioListTile<String>(
              title: const Text('无操作'),
              subtitle: const Text('扫码后不执行任何额外操作'),
              value: 'none',
              groupValue: _actionType,
              onChanged: (value) => setState(() => _actionType = value!),
            ),
            
            RadioListTile<String>(
              title: const Text('打开应用'),
              subtitle: const Text('扫码后自动打开指定的应用'),
              value: 'app',
              groupValue: _actionType,
              onChanged: (value) => setState(() => _actionType = value!),
            ),
            
            RadioListTile<String>(
              title: const Text('打开网址'),
              subtitle: const Text('扫码后自动在浏览器中打开指定网址'),
              value: 'url',
              groupValue: _actionType,
              onChanged: (value) => setState(() => _actionType = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppSelectionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择应用',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // 应用包名输入
            TextField(
              decoration: const InputDecoration(
                labelText: '应用包名',
                hintText: '例如：com.tencent.mm（微信）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.android),
                helperText: '输入要打开的应用的完整包名',
              ),
              controller: TextEditingController(text: _targetPackage),
              onChanged: (value) {
                setState(() {
                  _targetPackage = value;
                  _selectedAppName = value.isNotEmpty ? _getAppDisplayName(value) : '';
                });
              },
            ),
            
            const SizedBox(height: 12),
            
            // 常用应用包名提示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '常用应用包名：',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '微信：com.tencent.mm\n'
                    'QQ：com.tencent.mobileqq\n'
                    '支付宝：com.eg.android.AlipayGphone\n'
                    '淘宝：com.taobao.taobao\n'
                    '抖音：com.ss.android.ugc.aweme\n'
                    'Chrome：com.android.chrome',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '提示：可以通过应用详情页面或开发者工具查看应用包名',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlConfigSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '网址配置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            TextField(
              decoration: const InputDecoration(
                labelText: '目标网址',
                hintText: 'https://www.example.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              controller: TextEditingController(text: _targetUrl),
              onChanged: (value) => _targetUrl = value,
              keyboardType: TextInputType.url,
            ),
            
            const SizedBox(height: 8),
            
            const Text(
              '支持的网址格式：\n'
              '• https://www.example.com\n'
              '• http://192.168.1.100:8080\n'
              '• 自定义协议：myapp://action',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '测试功能',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _actionType == 'none' ? null : _testAction,
                icon: const Icon(Icons.play_arrow),
                label: const Text('测试后置操作'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            const Text(
              '点击测试按钮可以预览配置的后置操作是否正常工作',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentVariableSection() {
    // 获取当前环境变量值
    const String envActionType = String.fromEnvironment('EASTER_EGG_ACTION_TYPE', defaultValue: 'none');
    const String envTargetPackage = String.fromEnvironment('EASTER_EGG_TARGET_PACKAGE', defaultValue: '');
    const String envTargetUrl = String.fromEnvironment('EASTER_EGG_TARGET_URL', defaultValue: '');
    
    bool hasEnvConfig = envActionType != 'none' || envTargetPackage.isNotEmpty || envTargetUrl.isNotEmpty;
    
    return Card(
      color: hasEnvConfig ? Colors.green.shade50 : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasEnvConfig ? Icons.check_circle : Icons.build, 
                  color: hasEnvConfig ? Colors.green.shade700 : Colors.grey.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  hasEnvConfig ? '构建时配置（已启用）' : '构建时配置',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: hasEnvConfig ? Colors.green.shade700 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            if (hasEnvConfig) ...[
              Text(
                '当前环境变量配置：',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EASTER_EGG_ACTION_TYPE=$envActionType',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                    if (envTargetPackage.isNotEmpty)
                      Text(
                        'EASTER_EGG_TARGET_PACKAGE=$envTargetPackage',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    if (envTargetUrl.isNotEmpty)
                      Text(
                        'EASTER_EGG_TARGET_URL=$envTargetUrl',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            const Text(
              '开发者可以通过环境变量在构建时预设后置操作：\n\n'
              'flutter build apk --dart-define=EASTER_EGG_ACTION_TYPE=app \\\n'
              '  --dart-define=EASTER_EGG_TARGET_PACKAGE=com.example.app\n\n'
              'flutter build apk --dart-define=EASTER_EGG_ACTION_TYPE=url \\\n'
              '  --dart-define=EASTER_EGG_TARGET_URL=https://example.com\n\n'
              '用户可以在界面中修改这些默认配置。',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }


  // 测试后置操作
  Future<void> _testAction() async {
    switch (_actionType) {
      case 'app':
        if (_targetPackage.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('测试配置：打开应用 $_selectedAppName ($_targetPackage)'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('请先输入应用包名'),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;
      case 'url':
        if (_targetUrl.isNotEmpty) {
          try {
            // 使用url_launcher打开网址
            final Uri uri = Uri.parse(_targetUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('成功打开网址：$_targetUrl'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('无法打开网址：$_targetUrl'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('打开网址出错：$e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('请先输入要打开的网址'),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;
    }
  }
}
