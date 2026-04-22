import 'package:flutter/material.dart';
import '../../../models/reader_settings.dart';

/// 详细设置弹窗
class DetailedSettingsDialog extends StatelessWidget {
  final ReaderSettings settings;
  final Function(ReaderSettings) onSettingsChanged;

  const DetailedSettingsDialog({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  /// 显示详细设置弹窗
  static void show(
    BuildContext context, {
    required ReaderSettings settings,
    required Function(ReaderSettings) onSettingsChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      isScrollControlled: true,
      builder: (context) => DetailedSettingsDialog(
        settings: settings,
        onSettingsChanged: onSettingsChanged,
      ),
    );
  }

  /// 创建设置更新回调的辅助方法
  void _updateSettings({
    double? lineHeight,
    double? paragraphSpacing,
    double? indentSize,
    int? themeIndex,
  }) {
    onSettingsChanged(settings.copyWith(
      lineHeight: lineHeight,
      paragraphSpacing: paragraphSpacing,
      indentSize: indentSize,
      themeIndex: themeIndex,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '详细设置',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          // 行间距
          Row(
            children: [
              const Expanded(
                child: Text('行间距',
                    style: TextStyle(color: Colors.white70)),
              ),
              Expanded(
                child: Slider(
                  value: settings.lineHeight,
                  min: 1.2,
                  max: 3.0,
                  divisions: 18,
                  label: settings.lineHeight.toStringAsFixed(1),
                  onChanged: (v) => _updateSettings(lineHeight: v),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  settings.lineHeight.toStringAsFixed(1),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 段间距
          Row(
            children: [
              const Expanded(
                child: Text('段间距',
                    style: TextStyle(color: Colors.white70)),
              ),
              Expanded(
                child: Slider(
                  value: settings.paragraphSpacing,
                  min: 0,
                  max: 24,
                  divisions: 24,
                  label: settings.paragraphSpacing.round().toString(),
                  onChanged: (v) => _updateSettings(paragraphSpacing: v),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  settings.paragraphSpacing.round().toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 首行缩进
          Row(
            children: [
              const Expanded(
                child: Text('首行缩进',
                    style: TextStyle(color: Colors.white70)),
              ),
              Expanded(
                child: Slider(
                  value: settings.indentSize,
                  min: 0,
                  max: 4,
                  divisions: 4,
                  label: settings.indentSize.round().toString(),
                  onChanged: (v) => _updateSettings(indentSize: v),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  settings.indentSize.round().toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 主题选择
          const Align(
            alignment: Alignment.centerLeft,
            child:
                Text('阅读主题', style: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: ReaderSettings.themes.length,
              itemBuilder: (context, index) {
                final theme = ReaderSettings.themes[index];
                final isSelected = index == settings.themeIndex;
                return GestureDetector(
                  onTap: () => _updateSettings(themeIndex: index),
                  child: Container(
                    width: 50,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: theme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            isSelected ? Colors.white : Colors.white24,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '文',
                        style: TextStyle(color: theme.textColor),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
