import 'package:flutter/material.dart';
import '../services/update_service.dart';

/// 版本更新对话框
class UpdateDialog extends StatefulWidget {
  final ReleaseInfo releaseInfo;

  const UpdateDialog({
    Key? key,
    required this.releaseInfo,
  }) : super(key: key);

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.system_update, color: Colors.blue),
          const SizedBox(width: 8),
          const Text('发现新版本'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 版本信息
            _buildVersionInfo(),
            const SizedBox(height: 16),
            
            // 更新内容
            _buildReleaseNotes(),
            const SizedBox(height: 16),
            
            // 文件信息
            _buildFileInfo(),
            
            // 下载进度
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              _buildDownloadProgress(),
            ],
            
            // 错误信息
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorMessage(),
            ],
          ],
        ),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildVersionInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.new_releases, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '版本 ${widget.releaseInfo.version}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Text(
                  '点击更新以获得最新功能和修复',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '更新内容:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: SingleChildScrollView(
            child: Text(
              widget.releaseInfo.releaseNotes.isNotEmpty
                  ? widget.releaseInfo.releaseNotes
                  : '• 功能优化和错误修复\n• 性能提升和体验优化\n• 蓝牙连接稳定性改进',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileInfo() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              const Text('文件大小: ', style: TextStyle(fontSize: 12)),
              Text(
                UpdateService.formatFileSize(widget.releaseInfo.fileSize),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (widget.releaseInfo.checksum.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.security, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                const Text('包含校验和验证', style: TextStyle(fontSize: 12, color: Colors.green)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadProgress() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('下载进度:', style: TextStyle(fontSize: 14)),
            Text(
              '${(_downloadProgress * 100).toInt()}%',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: _downloadProgress,
          backgroundColor: Colors.grey.withOpacity(0.3),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
        const SizedBox(height: 4),
        if (_totalBytes > 0)
          Text(
            '${UpdateService.formatFileSize(_downloadedBytes)} / ${UpdateService.formatFileSize(_totalBytes)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    if (_isDownloading) {
      return [
        TextButton(
          onPressed: null,
          child: const Text('下载中...'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('稍后更新'),
      ),
      ElevatedButton(
        onPressed: _startUpdate,
        child: const Text('立即更新'),
      ),
    ];
  }

  void _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _errorMessage = null;
    });

    final success = await UpdateService.instance.downloadAndInstallApk(
      downloadUrl: widget.releaseInfo.downloadUrl,
      expectedChecksum: widget.releaseInfo.checksum.isNotEmpty 
          ? widget.releaseInfo.checksum 
          : null,
      onProgress: (received, total) {
        if (mounted) {
          setState(() {
            _downloadedBytes = received;
            _totalBytes = total;
            _downloadProgress = total > 0 ? received / total : 0.0;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _errorMessage = error;
          });
        }
      },
    );

    if (success && mounted) {
      // 下载成功，关闭对话框
      Navigator.of(context).pop(true);
      
      // 显示安装提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('APK下载完成，请在通知栏中点击安装'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }
}

/// 显示更新对话框的便捷方法
Future<bool?> showUpdateDialog(
  BuildContext context,
  ReleaseInfo releaseInfo,
) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => UpdateDialog(releaseInfo: releaseInfo),
  );
}
