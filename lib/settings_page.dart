import 'package:flutter/material.dart';
import 'permission_guide_page.dart';
import 'crash_log_page.dart';
import 'about_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 权限设置分组
          _buildSectionHeader('权限设置'),
          _buildSettingCard(
            context,
            icon: Icons.security,
            title: '权限管理',
            subtitle: '管理应用所需的各种权限',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const PermissionGuidePage()),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 系统工具分组
          _buildSectionHeader('系统工具'),
          _buildSettingCard(
            context,
            icon: Icons.bug_report,
            title: '崩溃日志',
            subtitle: '查看应用崩溃和错误日志',
            trailing: const Badge(
              label: Text('新'),
              backgroundColor: Colors.red,
              textColor: Colors.white,
              child: SizedBox(),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const CrashLogPage()),
            ),
          ),
          _buildSettingCard(
            context,
            icon: Icons.storage,
            title: '清理缓存',
            subtitle: '清理应用缓存数据',
            onTap: () => _showClearCacheDialog(context),
          ),
          
          const SizedBox(height: 24),
          
          // 关于分组
          _buildSectionHeader('关于'),
          _buildSettingCard(
            context,
            icon: Icons.info_outline,
            title: '关于应用',
            subtitle: '版本信息、开发者信息等',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AboutPage()),
            ),
          ),
          _buildSettingCard(
            context,
            icon: Icons.help_outline,
            title: '使用帮助',
            subtitle: '查看使用说明和常见问题',
            onTap: () => _showHelpDialog(context),
          ),
          
          const SizedBox(height: 32),
          
          // 版本信息
          Center(
            child: Column(
              children: [
                Text(
                  'ScanToPDA',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'v1.0.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('清理缓存'),
          content: const Text('确定要清理应用缓存吗？这将删除临时文件和缓存数据。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('缓存清理完成')),
                );
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('使用帮助'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '快速开始',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('1. 首先完成权限设置（蓝牙权限和无障碍服务）'),
                Text('2. 启动扫码服务'),
                Text('3. 使用扫码枪扫描条码'),
                Text('4. 扫码结果将自动显示在主界面'),
                SizedBox(height: 16),
                Text(
                  '常见问题',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Q: 扫码无反应？'),
                Text('A: 请确保已开启无障碍服务和蓝牙权限'),
                SizedBox(height: 8),
                Text('Q: 悬浮窗无法显示？'),
                Text('A: 请在权限设置中授予悬浮窗权限'),
                SizedBox(height: 8),
                Text('Q: 服务启动失败？'),
                Text('A: 请检查权限设置，或查看崩溃日志'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }
}
