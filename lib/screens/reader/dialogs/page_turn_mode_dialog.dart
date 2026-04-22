import 'package:flutter/material.dart';
import '../../../models/reader_settings.dart';

/// 翻页模式选择弹窗
class PageTurnModeDialog extends StatelessWidget {
  final PageTurnMode currentMode;
  final ValueChanged<PageTurnMode> onModeChanged;

  const PageTurnModeDialog({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  /// 显示翻页模式选择弹窗
  static void show(
    BuildContext context, {
    required PageTurnMode currentMode,
    required ValueChanged<PageTurnMode> onModeChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      isScrollControlled: true,
      builder: (context) => PageTurnModeDialog(
        currentMode: currentMode,
        onModeChanged: onModeChanged,
      ),
    );
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
                '翻页模式',
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
          // 翻页模式选项（使用 Wrap 布局，与原版一致）
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: PageTurnMode.values.map((mode) {
              final isSelected = mode == currentMode;
              return GestureDetector(
                onTap: () {
                  onModeChanged(mode);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.white38,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    mode.displayName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
