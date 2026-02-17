#!/bin/bash
# 截取多个页面的截图

echo "正在截取应用界面..."

# 等待一下确保窗口激活
sleep 1

# 截取当前屏幕
DISPLAY=:0 scrot /tmp/yuedu_main.png

echo "截图已保存到 /tmp/yuedu_main.png"
