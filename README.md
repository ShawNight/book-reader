# 悦读 Flutter (YueDu Flutter)

开源阅读器，支持导入本地 JSON 书源（兼容"阅读3.0"格式）。

## 功能特性

- **书源导入** - 支持 JSON 格式书源批量导入
- **书源净化** - 测试书源有效性，一键删除无效书源
- **多源搜索** - 多书源并发搜索，结果实时显示
- **搜索历史** - 自动保存搜索记录，快速重搜
- **书架管理** - 收藏/删除书籍，追踪阅读进度
- **一键阅读** - 点击书架书籍直接打开上次阅读位置
- **章节目录** - 搜索、排序、分组浏览，支持"继续阅读"
- **阅读器** - 多种翻页模式、主题切换、阅读设置
- **进度追踪** - 自动保存章节进度和滚动位置
- **离线缓存** - 自动缓存章节内容（30天有效期）
- **图片支持** - 自动识别和显示章节中的图片，点击图片可放大查看

## 快速开始

### 环境要求

- Flutter 3.0+
- Dart 3.0+

### 运行项目

```bash
# Linux 桌面版（推荐开发测试）
flutter run -d linux

# Android APK 构建
flutter build apk --debug    # Debug 版本
flutter build apk --release  # Release 版本
```

### 使用流程

#### 1. 导入书源
1. 点击底部「书源」标签
2. 点击右上角 `+` 按钮
3. 选择项目根目录下的 `书源.json`
4. 等待导入成功提示

#### 2. 搜索小说
1. 点击底部「书架」标签
2. 点击右上角搜索按钮 🔍
3. 输入小说名称（如"斗破"）
4. 点击搜索结果右侧的 ⊕ 按钮加入书架
5. 搜索记录自动保存，下次可点击历史快速搜索

#### 3. 开始阅读
1. 在书架中点击收藏的书籍
2. 首次阅读进入章节列表，之后直接打开上次阅读位置
3. 点击任意章节开始阅读
4. 点击屏幕显示/隐藏控制栏
5. 滚动进度自动保存，下次打开自动恢复

## 阅读器功能

### 阅读设置
| 设置项 | 范围 | 默认值 |
|--------|------|--------|
| 字体大小 | 12-32 | 18 |
| 行高 | 1.2-3.0 | 1.8 |
| 段间距 | 0-24 | 8 |
| 首行缩进 | 0-4 字符 | 2 |
| 上下边距 | - | 16 |
| 左右边距 | - | 16 |

### 预设主题
1. 米黄色（默认）
2. 护眼绿
3. 夜间模式
4. 纯白
5. 羊皮纸
6. 蓝色护眼

### 翻页模式
- **滑动翻页** - 左右滑动切换页面
- **覆盖翻页** - 页面覆盖效果
- **仿真翻页** - 真实书页翻转动画（含阴影和边缘效果）
- **滚动模式** - 垂直滚动阅读

### 触屏操作
- 点击屏幕左侧 30%：上一页
- 点击屏幕右侧 30%：下一页
- 点击屏幕中间：显示/隐藏控制栏

## 书架功能

### 添加书籍
- **方式1**：搜索结果点击 ⊕ 按钮
- **方式2**：章节列表页点击书签图标

### 管理书籍
- 查看阅读进度（读到：第X章）
- 左滑删除书籍
- 显示书籍信息（作者、来源、最新章节）
- **多种排序方式**：
  - 按添加时间
  - 按书名（A-Z / Z-A）
  - 按作者（A-Z / Z-A）
  - 按最近阅读时间
  - 按阅读进度
  - 支持升序/降序切换
- **批量管理**（长按进入多选模式）：
  - 全选 / 取消全选
  - 批量删除
  - 批量标记已读 / 未读

### 阅读进度
- 点击书籍直接打开上次阅读位置
- 自动保存章节索引和滚动位置
- 章节列表页有"继续阅读"按钮（▶）

## 书源净化

### 测试书源有效性
1. 进入「书源」标签页
2. 点击右上角净化图标（扫帚）
3. 点击「开始测试」按钮
4. 等待测试完成，查看结果

### 筛选和净化
- 按状态筛选：全部 / 有效 / 无效 / 待测试
- 查看详细信息：响应时间、结果数量、错误信息
- 点击「净化」按钮删除所有无效书源

### 测试说明
- 使用默认关键词"斗罗"进行搜索测试
- 每个书源超时时间为 8 秒
- 最多同时测试 5 个书源
- 返回至少 1 个搜索结果即视为有效

## 数据存储

```
~/.local/share/yuedu_flutter/ (Linux)
~/Documents/ (其他平台)
├── bookshelf.json           # 书架数据
├── reader_settings.json     # 阅读设置
├── search_history.json      # 搜索历史
├── book_sources/
│   └── sources.json         # 书源数据
└── chapter_cache/           # 章节缓存
```

### 备份数据
```bash
# 备份书架
cp ~/.local/share/yuedu_flutter/bookshelf.json ~/backup/

# 备份书源
cp -r ~/.local/share/yuedu_flutter/book_sources ~/backup/
```

## 技术栈

| 技术 | 用途 |
|------|------|
| Flutter 3.x | 跨平台框架 |
| Riverpod | 状态管理 |
| Dio | 网络请求 |
| html | HTML 解析 |
| json_annotation | JSON 序列化 |
| path_provider | 文件存储 |
| crypto | MD5 缓存键 |

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── models/                   # 数据模型
│   ├── book_source.dart      # 书源模型
│   ├── book.dart             # 书籍模型
│   ├── reader_settings.dart  # 阅读设置
│   └── source_test_result.dart  # 书源测试结果
├── services/                 # 业务逻辑
│   ├── book_source_service.dart
│   ├── search_service.dart
│   ├── search_history_service.dart
│   ├── bookshelf_service.dart
│   ├── reader_settings_service.dart
│   ├── chapter_cache_service.dart
│   └── source_test_service.dart  # 书源测试服务
├── widgets/                  # 可复用组件
│   └── simulation_page_turn.dart  # 仿真翻页动画
└── screens/                  # 界面
    ├── home_screen.dart
    ├── search_screen.dart
    ├── chapter_list_screen.dart
    ├── reader_screen.dart
    └── source_purify_screen.dart  # 书源净化界面
```

## 已知问题

- [ ] 部分书源规则可能不兼容
- [ ] 阅读统计功能待开发

## 相关文档

- [CLAUDE.md](CLAUDE.md) - 开发指南（架构、实现细节）
- [docs/DOCUMENTATION_GUIDE.md](docs/DOCUMENTATION_GUIDE.md) - 文档维护规范
- [docs/PROJECT_SPEC.md](docs/PROJECT_SPEC.md) - 项目规格说明
- [docs/BOOKSHELF_GUIDE.md](docs/BOOKSHELF_GUIDE.md) - 书架功能详细指南
- [docs/UI_GUIDE.md](docs/UI_GUIDE.md) - 界面设计规范
- [scripts/](scripts/) - 开发脚本和测试文件

## 注意事项

1. **书源格式** - 必须是阅读3.0兼容的 JSON 格式
2. **网络要求** - 搜索和加载章节需要网络连接
3. **内容版权** - 仅供学习 Flutter 开发，请支持正版
4. **数据备份** - 数据存储在本地，建议定期备份

## License

MIT
