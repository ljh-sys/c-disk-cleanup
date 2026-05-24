# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

C 盘清理分析技能——一键扫描 C 盘关键路径，AI 为每个条目生成中文描述和风险定级（安全/需确认/危险），生成只读 HTML 分析报告。

## 核心文件与架构

| 文件 | 职责 |
|------|------|
| `skill.md` | 技能定义（元数据、触发条件、工作流程、注意事项） |
| `scan.ps1` | PowerShell 扫描脚本，并行 Job 扫描 11 个区域，输出 `~\.cleanup\data.json` |
| `make-report.py` | Python 报告生成器，HTML 模板内嵌在 `TEMPLATE` 变量中 |
| `report-template.html` | 仅作为模板缓存副本，权威模板在 `make-report.py` 的 `TEMPLATE` 变量中 |

## 数据流

```
scan.ps1 → ~\.cleanup\data.json
                    ↓
          make-report.py ← ~\.cleanup\ai-descriptions.json (AI 缓存)
                    ↓
          ~\Desktop\C盘清理分析报告.html
```

- 首次扫描发现新路径时：`make-report.py` 输出 `~\.cleanup\ai-needed.json` → AI 分析后写入 `ai-descriptions.json` → 重新运行 `make-report.py`
- AI 描述缓存持久化：后续扫描相同路径直接复用，仅新增/变更路径需重新生成

## 关键设计决策

- **分离关注点**：`scan.ps1` 仅按目录位置分类，不做风险评估。所有描述和风险定级由 AI 完成
- **模板嵌入**：HTML 模板完全内嵌在 `make-report.py` 的 `TEMPLATE` 字符串中。修改模板时改 Python 文件，不要单独改 `report-template.html`
- **白名单**：`~\.cleanup\whitelist.json` 中的路径在扫描时跳过
- **报告只读**：无复选框、筛选、搜索等交互功能
- **不要硬编码用户名**：使用 `$env:USERNAME` 和 `$env:USERPROFILE`
- **表格表头不使用 `position: sticky`**（Chromium 渲染 bug）
- **侧边栏底部留白 50vh** 确保所有项目可点击

## 常用命令

```bash
# 运行完整扫描（生成数据 + 生成报告 + 打开浏览器）
powershell -ExecutionPolicy Bypass -File scan.ps1

# 仅重新生成报告（需要已有 data.json）
python make-report.py

# 查看 AI 待处理列表
cat ~/.cleanup/ai-needed.json
```
