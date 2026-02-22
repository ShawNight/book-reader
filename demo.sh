#!/bin/bash

echo "╔════════════════════════════════════════╗"
echo "║     悦读 Flutter - 阅读器测试演示      ║"
echo "╚════════════════════════════════════════╝"
echo ""

# 检查应用是否已编译
if [ ! -f "./build/linux/x64/debug/bundle/yuedu_flutter" ]; then
    echo "⚠️  应用未编译，开始编译..."
    /home/shawnight/flutter/bin/flutter build linux --debug
fi

echo "📱 启动应用..."
echo ""

# 启动应用
./build/linux/x64/debug/bundle/yuedu_flutter &

sleep 3

echo ""
echo "✅ 应用已启动！"
echo ""
echo "📖 使用步骤:"
echo "  1. 点击底部【书源】标签"
echo "  2. 点击右上角➕按钮"
echo "  3. 选择项目目录下的【书源.json】文件"
echo "  4. 等待提示【成功导入 5 个书源】"
echo ""
echo "  5. 点击底部【书架】标签"
echo "  6. 点击右上角🔍搜索按钮"
echo "  7. 输入【斗破】或【斗罗】"
echo "  8. 点击搜索结果查看章节"
echo "  9. 开始阅读！"
echo ""
echo "💡 提示:"
echo "  • 阅读界面点击屏幕显示控制栏"
echo "  • 左右滑动翻页"
echo "  • 点击右上角📋查看所有章节"
echo ""
echo "按 Ctrl+C 退出应用..."
