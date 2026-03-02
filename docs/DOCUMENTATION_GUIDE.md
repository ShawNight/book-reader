# 文档维护指南

本文档定义了项目的文档结构和维护规范，确保每次功能开发都能保持文档的同步更新。

## 文档结构

```
book-reader/
├── README.md                 # 项目入口文档（用户视角）
├── CLAUDE.md                 # AI 开发指南（开发者视角）
├── docs/
│   ├── README.md             # 文档索引
│   ├── PROJECT_SPEC.md       # 项目规格（不变）
│   ├── FEATURE_*.md          # 功能详细文档（按功能命名）
│   ├── UI_GUIDE.md           # 界面设计规范
│   └── flutter-*.md          # 技术文档
├── scripts/                  # 开发脚本
└── lib/                      # 源代码
```

## 文档职责

| 文档 | 目标读者 | 内容 | 更新时机 |
|------|----------|------|----------|
| README.md | 用户 | 功能介绍、使用方法、快速开始 | 新功能上线 |
| CLAUDE.md | AI/开发者 | 架构、实现细节、代码规范 | 架构变更、新服务/模型 |
| docs/FEATURE_*.md | 用户/开发者 | 单个功能的详细说明 | 该功能开发时 |
| docs/UI_GUIDE.md | 开发者 | 界面设计规范 | UI 变更时 |

## 开发流程中的文档更新

### 1. 开发前（规划阶段）
- [ ] 在 `docs/` 创建 `FEATURE_xxx.md` 描述功能设计
- [ ] 如有架构变更，更新 `CLAUDE.md` 的架构部分

### 2. 开发中（实现阶段）
- [ ] 新增 Model → 更新 `CLAUDE.md` 的 Layer Structure
- [ ] 新增 Service → 更新 `CLAUDE.md` 的服务列表
- [ ] 新增 Screen → 更新 `CLAUDE.md` 的界面列表
- [ ] 修改数据存储 → 更新 `CLAUDE.md` 的 Data Persistence

### 3. 开发后（完成阶段）
- [ ] 更新 `README.md` 的功能特性列表
- [ ] 更新 `CLAUDE.md` 的 Implemented Features
- [ ] 更新 Known Issues（如有）
- [ ] 完善 `docs/FEATURE_xxx.md` 的使用说明

## 文档模板

### 新功能文档模板 (docs/FEATURE_xxx.md)

```markdown
# 功能名称

## 功能概述
简要描述功能用途。

## 使用方法
1. 步骤一
2. 步骤二

## 界面说明
（可选）截图和界面元素说明。

## 技术实现
- 相关文件：`lib/xxx.dart`
- 数据模型：`ModelName`
- 服务：`ServiceName`

## 配置项
| 配置 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| xxx  | 类型 | 值     | 说明 |

## 已知问题
- [ ] 问题描述
```

### README.md 功能条目模板

```markdown
- **功能名称** - 简要描述（NEW！）
```

### CLAUDE.md 实现功能模板

```markdown
### 功能名称 (ScreenName)
- **子功能1**：说明
- **子功能2**：说明
- **配置项**：列表
```

## 快速检查清单

### 新增 Model 时
```
□ lib/models/xxx.dart 创建
□ CLAUDE.md Layer Structure 更新
□ CLAUDE.md 数据存储更新（如涉及）
```

### 新增 Service 时
```
□ lib/services/xxx_service.dart 创建
□ CLAUDE.md Layer Structure 更新
□ CLAUDE.md Important Implementation Details 更新
```

### 新增 Screen 时
```
□ lib/screens/xxx_screen.dart 创建
□ CLAUDE.md Layer Structure 更新
□ CLAUDE.md Implemented Features 更新
□ README.md 功能列表更新
□ docs/FEATURE_xxx.md 创建（如需要）
```

### 修改配置/设置时
```
□ CLAUDE.md 配置说明更新
□ README.md 配置表格更新
```

### 修复/发现 Bug 时
```
□ CLAUDE.md Known Issues 添加或移除
□ README.md 已知问题更新
```

## 文档更新原则

1. **同步更新**：代码和文档同时修改，不要事后补
2. **用户视角**：README.md 面向用户，避免技术术语
3. **开发者视角**：CLAUDE.md 面向开发者，包含实现细节
4. **增量更新**：新功能创建新文档，不要无限扩展现有文档
5. **保持简洁**：文档不宜过长，复杂功能拆分多个文档

## AI 开发提示

当使用 Claude Code 开发时，可以在请求中添加：

```
请开发 xxx 功能，并同步更新相关文档：
1. CLAUDE.md - 架构和实现细节
2. README.md - 功能说明
3. docs/FEATURE_xxx.md - 功能详细文档（如需要）
```

或者使用简化版：

```
开发 xxx 功能，记得更新文档
```

Claude Code 会根据本文档的规范自动更新相关文档。
