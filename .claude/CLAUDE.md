# cm-plugin-workflow

spec-driven 的 Claude Code 自动化开发工作流分发包，**专用于 Chrome 浏览器扩展（MV3）开发**：需求文档 → 开发规格 → 自动开发 → QA/商店合规 → 文档同步。本仓库的「源码」是 prompt 资产（Markdown），产物安装到 `~/.claude/`。上游为 kingxiaozhe/cm-workflow（通用多工种版），本仓库是其插件领域定制 fork，前缀 `cm-plugin:` 与上游 `cm:` 可同机共存。

## 技术栈

- 语言: Markdown（prompt 资产）+ Bash（安装与可视化脚本）+ PowerShell（Windows 安装器）
- 框架: 无。Claude Code 原生扩展机制——commands / skills / agents / templates
- 包管理: 无。分发靠 `install.sh` / `install.ps1` 拷贝到 `~/.claude/`
- 版本控制: remote
- 交付形态: 开发者工具（Claude Code 插件包，纯 Markdown + bash，无构建产物）
- 业务地图: 跳过（prompt 资产库，codebase-context 不适用；README 的带注释目录树即业务地图）

## 常用命令

- 安装到本机: `./install.sh`（含覆盖确认，装完提示跑 /cm-plugin:check）
- Windows 安装: `powershell -ExecutionPolicy Bypass -File install.ps1`
- 一致性自检: `/cm-plugin:check`（**本仓库唯一的自动化测试，改任何框架文件后必跑**）
- 查看版本: `cat VERSION`
- 可视化预览: `templates/pixel/cm-pixel.sh --demo`、`templates/dashboard/serve.sh {specs路径}`

无 build / lint / 单元测试——不存在构建产物，质量门是 `/cm-plugin:check` + dogfood 实跑。

## 目录结构

```text
commands/                     # 斜杠命令 → ~/.claude/commands/
├── cm-plugin:{rewrite,scout,init,prd,ai,fix,refactor,idea,check}.md   # rewrite=重写直通流水线（主入口）,scout=选品评估
├── cm-plugin-ai-nodes/       # cm-plugin:ai 的 N1–N8 节点，按需加载
└── cm-plugin-prd-modes/      # cm-plugin:prd 的 greenfield/brownfield/change-mode
skills/                       # 工种能力 → ~/.claude/skills/{name}/SKILL.md —— skill 管技术
├── cm-plugin-extension-engineer/   # 核心工种：扩展本体（manifest/SW/content script/表面/存储/消息）
├── cm-plugin-{ui,backend,qa,devops}-engineer/、cm-plugin-product-manager/、cm-plugin-doc-syncer/
└── codebase-context/、idea-to-prd/、darwin-skill/   # 独立工具，不进 N1–N8
agents/                       # 并行子 agent → ~/.claude/agents/ —— agent 管纪律
│                             # extension / ui / backend 三个（串行把关角色不做 agent）
templates/                    # rules 骨架（含 chrome-extension.md）/ hooks / statusline / dashboard / pixel / auto-update
docs/                         # 使用手册、重构流程设计
VERSION                       # 单一版本源，与 cm-plugin:check 基线号双写
```

## 核心架构原则

- **agent 管纪律，skill 管技术**：并行干活的做 agent（extension/ui/backend），串行把关的做 skill（产品/QA/devops/doc-syncer）。新增角色前先归到这两类之一。
- **引用即契约**：本仓库历史缺陷全属「引用断链」——改名残留、匹配表缺项、死角色、失效命令引用。任何跨文件引用都由 `/cm-plugin:check` 机器化校验。
- **模板层是团队定制入口**：公司规范沉淀进 `templates/rules/`，所有项目 `/cm-plugin:init` 出的 rules 自动带公司基因。
- **插件领域红线**：manifest 权限最小化（agent 层"权限只减不增"）、商店提审强制人工确认、商店合规检查单只举旗不定性——这三条是本 fork 区别于上游的领域性约束，不得放宽。
- **命令间隔离（随上游 2026-07-18 确立）**：修改任一 `cm-plugin:` 命令不得动到其他命令的流程文件；命令 A 需要命令 B 的东西,一律做成 A 读 B 的**落盘物**(档案/清单/备忘),不改 B 的文本。rewrite 流水线即此模式:它按序执行下游命令并消费其落盘物(scout 报告/design-baseline/prd.md),不改写任何下游命令文本。唯一豁免:发版时 cm-plugin:check.md 的版本基线行(双写记账,非流程)。
- **与上游共存**：所有安装产物带 `cm-plugin` 命名（commands 前缀、skills/agents 名、templates/cm-plugin-*、~/.cm-plugin-workflow/）——与上游 cm-workflow 的安装物零交集，改名时必须维持这一点，否则两边自动更新器会互相"自愈"覆盖。

## 规则

@rules/coding-style.md
@rules/testing.md
@rules/security.md
@rules/git-workflow.md
