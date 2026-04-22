import 'package:flutter/material.dart';

/// 字号调节弹窗
class FontSizeDialog extends StatelessWidget {
  final double fontSize;
  final ValueChanged<double> onFontSizeChanged;

  const FontSizeDialog({
    super.key,
    required this.fontSize,
    required this.onFontSizeChanged,
  });

  /// 显示字号调节弹窗
  static void show(
    BuildContext context, {
    required double fontSize,
    required ValueChanged<double> onFontSizeChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      isScrollControlled: true,
      builder: (context) => FontSizeDialog(
        fontSize: fontSize,
        onFontSizeChanged: onFontSizeChanged,
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
                '字体大小',
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
          // 字体大小调节
          Row(
            children: [
              const Text('A',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: fontSize,
                  min: 12,
                  max: 32,
                  divisions: 20,
                  label: fontSize.round().toString(),
                  onChanged: onFontSizeChanged,
                ),
              ),
              const SizedBox(width: 8),
              const Text('A',
                  style: TextStyle(color: Colors.white70, fontSize: 22)),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  fontSize.round().toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
