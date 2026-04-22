import 'package:flutter/material.dart';
import '../../../services/batch_download_service.dart';

/// 下载状态图标组件
class DownloadStatusIcon extends StatelessWidget {
  final DownloadStatus status;

  const DownloadStatusIcon({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    if (status == DownloadStatus.downloaded) {
      return const Icon(
        Icons.offline_pin,
        size: 16,
        color: Colors.green,
      );
    } else if (status == DownloadStatus.downloading) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (status == DownloadStatus.failed) {
      return const Icon(
        Icons.error_outline,
        size: 16,
        color: Colors.red,
      );
    } else {
      return Icon(
        Icons.cloud_off_outlined,
        size: 16,
        color: Colors.grey[400],
      );
    }
  }
}
