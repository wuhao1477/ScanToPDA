import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于应用'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 应用信息卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.qr_code_scanner,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ScanToPDA',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '扫码助手',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'v1.0.0',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '专业的PDA扫码枪监听工具，支持蓝牙连接、广播监听、崩溃日志记录等功能。',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 功能特性
            _buildSectionTitle('功能特性', Icons.star),
            const SizedBox(height: 12),
            _buildFeatureItem(
              icon: Icons.bluetooth,
              title: '蓝牙扫码监听',
              description: '实时监听蓝牙扫码枪输入，自动转换为PDA广播',
            ),
            _buildFeatureItem(
              icon: Icons.radio,
              title: '广播接收器',
              description: '监听系统广播，捕获各类PDA扫码数据',
            ),
            _buildFeatureItem(
              icon: Icons.open_in_new,
              title: '悬浮窗显示',
              description: '便捷的悬浮窗界面，随时查看扫码状态',
            ),
            _buildFeatureItem(
              icon: Icons.bug_report,
              title: '崩溃日志',
              description: '自动记录应用崩溃信息，便于问题排查',
            ),
            _buildFeatureItem(
              icon: Icons.accessibility,
              title: '无障碍服务',
              description: '全局按键监听，确保后台正常工作',
            ),

            const SizedBox(height: 24),

            // 开发者信息
            _buildSectionTitle('开发者信息', Icons.person_outline),
            const SizedBox(height: 12),
            _buildDeveloperCard(),

            const SizedBox(height: 24),

            // 开源协议
            _buildSectionTitle('开源协议', Icons.gavel),
            const SizedBox(height: 12),
            _buildLicenseCard(),

            const SizedBox(height: 24),

            // 使用说明
            _buildSectionTitle('使用说明', Icons.help_outline),
            const SizedBox(height: 12),
            _buildInstructionCard(),

            const SizedBox(height: 24),

            // 技术信息
            _buildSectionTitle('技术信息', Icons.info_outline),
            const SizedBox(height: 12),
            _buildTechInfoCard(),

            const SizedBox(height: 24),

            // 联系方式
            _buildSectionTitle('支持与反馈', Icons.contact_support),
            const SizedBox(height: 12),
            _buildContactCard(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.blue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInstructionStep(
              step: '1',
              title: '开启无障碍服务',
              description: '前往设置 > 无障碍 > 键盘无障碍服务，开启服务权限',
            ),
            _buildInstructionStep(
              step: '2',
              title: '启动监听服务',
              description: '点击"启动服务"按钮，开始监听扫码枪输入',
            ),
            _buildInstructionStep(
              step: '3',
              title: '开启悬浮窗（可选）',
              description: '启用悬浮窗显示，方便随时查看扫码状态',
            ),
            _buildInstructionStep(
              step: '4',
              title: '开始扫码',
              description: '使用蓝牙扫码枪扫描条码，应用会自动捕获并处理',
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep({
    required String step,
    required String title,
    required String description,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  step,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: Colors.blue.withOpacity(0.3),
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTechInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow('开发框架', 'Flutter 3.x'),
            _buildInfoRow('编程语言', 'Dart + Kotlin'),
            _buildInfoRow('最低Android版本', 'Android 6.0 (API 23)'),
            _buildInfoRow('权限需求', '蓝牙、悬浮窗、无障碍'),
            _buildInfoRow('数据存储', 'SQLite 本地数据库'),
            _buildInfoRow('架构模式', 'MVVM + 原生服务'),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.feedback, color: Colors.blue),
              title: const Text('问题反馈'),
              subtitle: const Text('遇到问题或有改进建议？'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // TODO: 打开反馈页面或邮箱
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.star_rate, color: Colors.orange),
              title: const Text('应用评分'),
              subtitle: const Text('如果觉得好用，请给我们评分'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // TODO: 打开应用商店评分
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.share, color: Colors.green),
              title: const Text('分享应用'),
              subtitle: const Text('推荐给更多需要的朋友'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // TODO: 分享应用
              },
            ),
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
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('开发者', 'wuhao1477'),
            const SizedBox(height: 8),
            _buildInfoRow('项目地址', 'github.com/wuhao1477/ScanToPDA'),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _launchUrl('https://github.com/wuhao1477/ScanToPDA'),
                icon: const Icon(Icons.code),
                label: const Text('访问GitHub仓库'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('协议类型', 'Apache License 2.0'),
            const SizedBox(height: 12),
            const Text(
              '本项目采用 Apache License 2.0 开源协议，允许商业使用，但在二次分发时必须：',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• 保留原始版权声明', style: TextStyle(fontSize: 14)),
                  Text('• 包含Apache License 2.0许可证', style: TextStyle(fontSize: 14)),
                  Text('• 标明对原始代码的修改', style: TextStyle(fontSize: 14)),
                  Text('• 注明原项目来源', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (BuildContext context) {
                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showLicenseDialog(context),
                        icon: const Icon(Icons.description),
                        label: const Text('查看完整协议'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _launchUrl('https://www.apache.org/licenses/LICENSE-2.0'),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('官方协议'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      // 如果无法打开URL，复制到剪贴板
      await Clipboard.setData(ClipboardData(text: url));
    }
  }

  void _showLicenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Apache License 2.0'),
          content: const SingleChildScrollView(
            child: Text(
              '''Apache License 2.0

Copyright 2025 wuhao1477

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

主要条款：
• 允许商业使用
• 允许修改和分发
• 必须保留版权声明
• 必须包含许可证副本
• 修改后的文件必须标明更改
• 不提供任何担保''',
              style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _launchUrl('https://www.apache.org/licenses/LICENSE-2.0');
              },
              child: const Text('查看完整版'),
            ),
          ],
        );
      },
    );
  }
}
