# C 盘清理分析 · C Drive Cleanup Skill

> **Windows only.** 一键扫描 C 盘，AI 为你生成中文清理分析报告。

一个 Claude Code 技能，用 PowerShell 并行扫描 C 盘 11 个关键区域，AI 为每个目录/文件生成中文描述和风险定级（安全 / 需确认 / 危险），输出单文件只读 HTML 报告。

![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-blue)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue)
![Python](https://img.shields.io/badge/python-3.6%2B-blue)

## 效果

- 🔍 **覆盖 11 个区域**：AppData、ProgramData、Windows 目录、Program Files、回收站、注册表启动项等
- 🤖 **AI 驱动分析**：所有描述和风险等级由 AI 根据路径实时生成，不做硬编码规则
- 📊 **只读 HTML 报告**：磁盘概览 + 使用率进度条 + 按类别分组表格 + 侧边栏导航
- 🌐 **中/英文切换**：右上角一键切换，偏好保存到 localStorage
- 🟢🟡🔴 **三级风险定级**：安全（绿）/ 需确认（黄）/ 危险（红），色标直观
- 💾 **AI 缓存持久化**：已分析的路径自动缓存，后续扫描直接复用
- ⚡ **并行扫描**：PowerShell 多 Job 并发，30-90 秒完成全盘扫描

## 安装

### 方式一：npx 安装（推荐）

```bash
npx skills add ljh-sys/c-disk-cleanup --skill c-disk-cleanup
```

### 方式二：把下面这段话发给 AI

> 帮我安装 `c-disk-cleanup` 这个 Claude Code skill。请按下面步骤做：
>
> 1. 确保 `~/.claude/skills/` 目录存在（不存在就创建）
> 2. 执行 `git clone https://github.com/ljh-sys/c-disk-cleanup.git ~/.claude/skills/c-disk-cleanup`
> 3. 验证：`ls ~/.claude/skills/c-disk-cleanup/` 应该看到 `SKILL.md`、`scan.ps1`、`make-report.py` 三项
> 4. 告诉我安装好了，之后我说"分析C盘"之类的话就会触发这个 skill

把这段话复制粘贴给 Claude Code 或任何有 shell 权限的 AI Agent，它会自动完成安装。

### 方式三：手动命令行

```bash
git clone https://github.com/ljh-sys/c-disk-cleanup.git ~/.claude/skills/c-disk-cleanup
```

### 触发方式

装好后，Claude Code 会在对话中自动发现并调用这个 skill。触发关键词：

- "分析C盘" / "扫描C盘" / "C盘分析"
- "C盘清理" / "清理C盘" / "C盘空间"
- "磁盘清理" / "看看C盘"
- "给我一份C盘清理报告"

## 使用流程

1. **触发扫描** — 对 AI 说"分析C盘"，Claude Code 自动调用 `scan.ps1`
2. **AI 分析** — 扫描完成后，AI 读取新增条目，逐个生成中文描述和风险定级
3. **生成报告** — `make-report.py` 合并扫描数据 + AI 描述，输出 HTML 报告到桌面
4. **浏览器预览** — 报告自动在浏览器中打开

```
你说"分析C盘"
    │
    ▼
scan.ps1 并行扫描
    │
    ▼
data.json  ────  AI 生成描述  ────  ai-descriptions.json
    │                                    │
    ▼                                    │
make-report.py  ◄────────────────────────┘
    │
    ▼
~\Desktop\C盘清理分析报告.html（浏览器自动打开）
```

## 扫描覆盖

| 扫描区域 | 说明 |
|----------|------|
| AppData/Local | 用户本地应用数据（Top 30） |
| AppData/Roaming | 用户漫游应用数据（Top 30） |
| AppData/LocalLow | 低完整性应用数据（Top 15） |
| User Dirs | 用户目录下的子目录（Top 40） |
| Dot Dirs | 用户目录下隐藏目录（点号开头） |
| ProgramData | 系统级应用数据（Top 20） |
| System Files | pagefile.sys / hiberfil.sys / swapfile.sys |
| Windows Dirs | Temp / Installer / SoftwareDistribution / Prefetch / Logs / WinSxS |
| Recycle Bin | 系统回收站 |
| Windows.old | 旧版 Windows 备份 |
| Program Files | Program Files 和 Program Files (x86)（Top 25） |
| Registry | 启动项孤立注册表键 |

## 风险定级

所有条目的描述和风险等级均由 AI 根据路径和名称实时分析生成，不做硬编码规则匹配。

| 等级 | 含义 | 示例 |
|------|------|------|
| 🟢 安全 | 可以安全删除 | 临时文件、缓存目录、回收站 |
| 🟡 需确认 | 需要用户确认后再操作 | 旧版本备份、不常用软件数据 |
| 🔴 危险 | 请勿删除 | 系统文件、驱动程序、正在使用的应用数据 |

## 文件结构

```
c-disk-cleanup/
├── SKILL.md              ← Skill 主文件：触发条件、工作流程、注意事项
├── README.md             ← 本文件
├── scan.ps1              ← PowerShell 扫描脚本（并行 Job，11 个扫描区域）
├── make-report.py        ← Python 报告生成器（HTML 模板内嵌）
└── report-template.html  ← HTML 模板缓存副本
```

运行时数据目录（`%USERPROFILE%\.cleanup\`）：

| 文件 | 说明 |
|------|------|
| `data.json` | 扫描结果 |
| `ai-descriptions.json` | AI 描述与风险定级缓存 |
| `ai-needed.json` | 待 AI 分析的新增路径 |
| `whitelist.json` | 白名单（跳过的路径） |

## 依赖

- **Windows 10 / 11**
- **PowerShell 5.1+**（系统自带）
- **Python 3.6+**（需在 PATH 中可用）

无需额外安装任何 Python 库（仅使用标准库 `json`、`os`、`collections`）。

## 设计原则

1. **脚本只分类，不定级** — `scan.ps1` 仅按目录位置归类，不包含硬编码风险评估，所有智能判断交给 AI
2. **AI 描述持久化** — 分析结果写入 `ai-descriptions.json`，重复扫描时直接复用缓存
3. **报告只读** — 不提供复选框、筛选、搜索等交互功能，用户自行判断并手动清理
4. **不硬编码用户名** — 始终使用 `$env:USERNAME` / `$env:USERPROFILE`
5. **白名单机制** — 用户可在 `whitelist.json` 中配置跳过路径

## 贡献

欢迎提 Issue 或 PR。改动请优先：

- 新增扫描区域在 `scan.ps1` 中添加并行 Job
- 修改报告样式在 `make-report.py` 的 `TEMPLATE` 变量中改（`report-template.html` 仅为缓存副本）
- 更新工作流程和注意事项写在 `SKILL.md` 中

## License

MIT © 2026 [ljh-sys](https://github.com/ljh-sys)
