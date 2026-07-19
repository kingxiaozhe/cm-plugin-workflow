# cm-plugin-workflow — Chrome 插件专用的 Claude Code 自动化开发工作流

一套 spec-driven 的 Claude Code 工作流，**专用于 Chrome 浏览器扩展（MV3）开发**：需求文档 → 开发规格 → 自动开发 → QA/商店合规 → 文档同步。

基于 [cm-workflow](https://github.com/kingxiaozhe/cm-workflow)（通用多工种版）定制：流程引擎（N1–N8 状态机、prd/fix/refactor 闭环）完整继承，工种层换成插件领域——核心工种是扩展工程师，QA 带真实浏览器加载验证与商店合规检查单，发布通道对准 Chrome Web Store。前缀 `cm-plugin:`，与上游 `cm:` 可同机共存（安装产物零交集）。

## 目录结构

```text
commands/                          # 斜杠命令（安装到 ~/.claude/commands/）
├── cm-plugin:rewrite.md           # ★重写直通流水线：链接 → 素材采集 → huashu-design 原型 → PRD → 拆specs → 开发到底
├── cm-plugin:scout.md             # 竞品插件重写机会评估（评论槽点/停更信号/源码功能盘点 → 机会评分卡；支持 --rewrite 素材模式）
├── cm-plugin:init.md              # 项目 .claude/ 初始化（CLAUDE.md + rules/，识别扩展脚手架与权限清单）
├── cm-plugin:prd.md               # 需求文档 → specs 三件套（requirements/design/tasks），支持 --change 变更模式
├── cm-plugin:ai.md                # 自动开发主循环（流程图状态机）
├── cm-plugin:fix.md               # 缺陷修复小闭环（复现→定位→防护网→最小修复→Codex审查→波及面回归→档案落盘）
├── cm-plugin:refactor.md          # 重构闭环（行为保持；设计见 docs/重构流程设计）
├── cm-plugin:idea.md              # 点子→PRD 访谈入口（加载 idea-to-prd 技能；流程上游，非 N1–N8 步骤）
├── cm-plugin:check.md             # 框架一致性自检（角色/命名/引用/配套/版本）
│
│  # 独立工具 skill（不属于 N1–N8 流程，按需使用）
│  skills/idea-to-prd/             # 点子→PRD 产品访谈搭档（新插件从零想法起步的前置工具）
│  skills/darwin-skill/            # 技能优化器（MIT 收编自 alchaincyf/darwin-skill，详见其 NOTICE.md）
│  skills/codebase-context/        # 代码库业务地图（scan/dev 两模式）
└── cm-plugin-ai-nodes/            # cm-plugin:ai 的 8 个流程节点，按需加载
    ├── N1-init.md                 # 初始化：解析路径、扫描 features、加载上下文
    ├── N2-enter-feature.md        # 进入 feature：断点恢复、依赖分析、串/并行计划
    ├── N3-execute-task.md         # 执行 task：按工种匹配 skill
    ├── N4-review.md               # AI 自审 + Codex 复审（环境不可用时降级）
    ├── N5-mark-done.md            # 标记 [x]、写 LESSONS.md
    ├── N6-qa-eval.md              # QA 评分决定是否触发 QA（含真实浏览器形态确认卡点）
    ├── N7-context.md              # 每个 task 后 /clear 重载 specs
    └── N8-finish.md               # 调用 doc-syncer、编制发布待决清单、输出总结

skills/                            # 工种 Skills（安装到 ~/.claude/skills/）—— skill 管技术
├── cm-plugin-extension-engineer/  # ★核心工种：扩展本体（manifest/service worker/content script/
│                                  #   popup/options/side panel/chrome.storage/消息通信），适配 WXT/Plasmo/CRXJS/原生
├── cm-plugin-ui-engineer/         # UI 还原（design-baseline → token 先行 → 原子还原 → BackstopJS ≤1%）
├── cm-plugin-backend-engineer/    # 配套后端（API 代理/鉴权/同步；扩展 CORS 与 token 鉴权、密钥只在服务端）
├── cm-plugin-qa-engineer/         # QA（测试补全、--load-extension 真实浏览器 E2E、商店合规检查单）
├── cm-plugin-product-manager/     # 产品（需求分析、歧义五问含权限敏感面、变更影响、业务验收走查）
├── cm-plugin-devops-engineer/     # 发布（打包 zip、权限 diff 核对、Chrome Web Store 提审强制人工确认）
└── cm-plugin-doc-syncer/          # 文档同步（README 权限清单/CLAUDE.md/rules/CHANGELOG）

agents/                            # 并行工种的子 agent 定义（安装到 ~/.claude/agents/）—— agent 管纪律
├── cm-plugin-extension-agent.md   # 只做指定任务、manifest 权限只减不增、不自行标记、规范汇报
├── cm-plugin-ui-agent.md          # 只碰展示层白名单、基准只读、改既有 token 强制上报
└── cm-plugin-backend-agent.md     # 范围外鉴权/权限改动强制上报
```

**分工原则**：并行干活的做 agent（extension/UI/后端），串行把关的做 skill（产品/QA/发布/doc-syncer）。

**可选外部依赖**：`npx skills add alchaincyf/huashu-design`（MIT）——无设计稿时在 /cm-plugin:prd 阶段生成高保真原型作为设计基准，未安装则 UI 由扩展工程师自行实现。

**rules 模板层**（`templates/rules/`，install.sh 装到 `~/.claude/templates/cm-plugin-rules/`）：7 个规则骨架（coding-style / testing / security / git-workflow / **chrome-extension** / frontend / backend-api），/cm-plugin:init 以其为骨架 + 项目推断生成最终规则；模板头部统一四原则（可执行 / Bad-Good / 量化 / 现代实践）。其中 `chrome-extension.md` 是插件铁律（权限最小化、MV3 约束、禁远程代码、消息契约集中管理）。**把团队规范沉淀进模板，所有项目 init 出的 rules 自动带团队基因**——这是团队定制的官方入口。

**收编素材**：QA 与 devops 两个 skill 的 `references/` 下的 CWS 检测模式清单、官方违规码表、提审材料清单、CI/CD 模板收编自 [quangpl/browser-extension-skills](https://github.com/quangpl/browser-extension-skills)（MIT），来源与改动见各 skill 目录的 `NOTICE.md`。

## 扩展 E2E harness 模板（templates/e2e/ → ~/.claude/templates/cm-plugin-e2e/）

MV3 扩展的 Playwright E2E 有一组固定坑，dogfood 实测全踩过一遍，现固化成**可拷贝的久经考验底座**（`extension-harness.ts` + `smoke.spec.example.ts`）。bootstrap T-005 直接拷入，每个新插件不再重踩：

- 系统 Chrome（2026 版）默认屏蔽 `--load-extension` → 须用 **Chrome for Testing**（harness 跨架构自动发现）
- `--headless=new`（旧 headless 不支持扩展，`headless:false` 在无头/CI 退化 flaky）
- SW **注册-停机竞态**（`acquireServiceWorker` 三路取先到）
- `sw.evaluate` 前须 `wakeServiceWorker` 取活引用（否则 `Worker was closed`）

给 N5「运行观察闸」提供了真能用的工具——不只是要求"真跑观察"，还给出怎么跑。

## 流程工具脚本（templates/scripts/ → ~/.claude/templates/cm-plugin-scripts/）

把 dogfood 实测中最痛的三个手工环节工具化，命令按需调用（都是有据可查的真实摩擦）：

- **cm-plugin-preflight.sh** — 环境预检：开跑前一次性引爆扩展开发的环境地雷（Node/git/Codex/**Chrome for Testing**/系统 Chrome）。最大的雷是系统 Chrome（2026 版）静默屏蔽 `--load-extension`，E2E 必须用 CfT。N1/R0 调用。
- **cm-plugin-codex.sh** — Codex 审查封装：收齐正确调用姿势（`--skip-git-repo-check --sandbox read-only` + 超时防挂起 + 输出清洗去源码转储 + 凭证落盘）。N4/prd/scout 的 Codex 调用优先用它，不裸调。
- **cm-plugin-log.sh** — JSONL 日志助手：自动 ISO8601 时间戳、原子追加、JSON 转义。杜绝手写 echo 的「先记账后落盘」「攒批挤同秒」两类实测错误。

## 插件领域的三条红线（区别于上游的领域性约束）

1. **manifest 权限只减不增**（agent 层硬约束）——任务范围外的权限新增/扩大必须停下上报
2. **Chrome Web Store 提审强制人工确认**——含权限变更的版本更新同样过闸
3. **商店合规检查单只举旗不定性**——权限最小化/单一用途/数据披露/禁远程代码/注入克制，举旗项交人裁决

## 安装

```bash
./install.sh          # macOS/Linux 一键安装（含覆盖确认），装完自动提示运行 /cm-plugin:check
```

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1   # Windows 版
```

或手动：

```bash
cp -r commands/* ~/.claude/commands/
cp -r skills/*   ~/.claude/skills/
cp -r agents/*   ~/.claude/agents/
```

安装/修改框架后运行 `/cm-plugin:check` 做一致性自检（角色存在性、命名一致、引用有效、配套完整、外部依赖 + **安装版本号**——反馈问题时请带上它）。

**与上游 cm-workflow 共存**：本包所有安装产物（命令前缀、skill/agent 名、`templates/cm-plugin-*`、`~/.cm-plugin-workflow/`）与上游零交集，两套可同机安装互不覆盖。

**Windows 说明**：核心工作流（commands/skills/agents）是纯 Markdown，Windows 原生可用；状态条 / 终端像素版 / serve.sh 是 bash+python3 脚本，在 WSL 或 Git Bash 中使用（浏览器像素版页面双击加 `?demo` 即可预览，不依赖脚本）。

## 执行可视化（终端原生优先）

**① 终端状态条（推荐，Claude Code 底部常驻）**——官方 statusLine 机制，零外部依赖：

```json
// ~/.claude/settings.json
"statusLine": {"type": "command", "command": "~/.claude/templates/cm-plugin-statusline.sh"}
```

效果：`⚙ ○○○●○○○○ N4 1.tab-organizer/T-005 · Codex复审第1轮`——八点节点条实时点亮；等人时整条变黄 `⏸ 等待人工`；数据来自 .cm-status.json（N1 写入 ~/.claude/cm-plugin-current-specs 指针定位）。

**② 内置任务清单镜像**——N2 进 feature 时任务自动镜像到 Claude Code 原生任务清单，N3/N5 同步状态，终端直接看勾选进度（无需配置）。

**③ 浏览器看板（备选，适合投屏/远程盯进度）**

```bash
templates/dashboard/serve.sh {specs路径}   # 浏览器打开提示的地址，2 秒自动刷新
```

**纯只读、零侵入**——只消费 specs 落盘文件（tasks.md 勾选 / METRICS / LESSONS），执行引擎无感知。

**④ 像素流水线（2D 像素游戏视角，演示/氛围屏首选）**——8 个像素工位对应 N1–N8：

```bash
templates/pixel/cm-pixel.sh            # 终端版（ANSI 像素，分屏挂一个 pane）
templates/pixel/cm-pixel.sh --demo     # 终端版演示模式（不需要真实运行）
templates/pixel/serve.sh {specs路径}   # 浏览器版（16-bit 风格，办公室大屏）
# 浏览器版演示模式: 打开地址后加 ?demo
```

精灵素材采用 Kenney Pixel Platformer 系列开源素材（CC0，已内嵌，单文件零依赖）。

## 自动更新（可选，macOS/Linux）

`templates/auto-update/` 提供会话级自动更新链路，install.sh 装到 `~/.cm-plugin-workflow/`，按提示在 settings.json 的 `hooks.SessionStart` 挂两条即启用：

- **cm-update.sh**：每次开会话异步检测上游新提交并自动重装；无新提交时做**逐文件字节级比对**，安装被改动/误删即自愈还原；**有工作流正在跑（.cm-status.json 为 running 且 30 分钟内活跃）则跳过本轮**。团队 fork 用 `CM_UPDATE_REMOTE` 环境变量指仓库，不要改脚本（会被自愈还原）
- **cm-announce.sh**：下次开会话时播报更新/自愈结果，报完即删

分工：更新器管"装的东西对不对"（机械，每会话），`/cm-plugin:check` 管"引用链断没断"（AI，改框架后跑），N1 预检管"这次运行环境行不行"（流程内）。

## 度量与双保险

- **METRICS.md**（specs 目录，N5 自动落盘）：每任务记录审查轮次、Codex 拦截、QA 结果、人工介入次数
- **RELEASES.md**（specs 目录，devops 落盘）：每次打包/提审/部署的审计记录，含权限 diff 与商店审核状态
- **templates/hooks/pre-commit-cm-task-check**：任务标记双保险 git hook（默认仅警告，`CM_TASK_CHECK_STRICT=1` 时阻断）

## 使用流程

**重写直通（已决定重写某插件时的主入口）：**

`/cm-plugin:rewrite {商店链接}`——一条命令走完全程：**R1** 素材采集（scout 素材模式：源码盘点+评论痛点，结论不设门）→ **R2** huashu-design 生成 UI 原型（唯一新增卡点：设计方向确认）→ **R3** 输出 PRD（功能三态标记：保留/改进/舍弃）→ **R4** /cm-plugin:prd 拆 specs（规格摘要卡人审）→ **R5** /cm-plugin:ai 开发到 N8 发布待决清单。中断可幂等续跑。

**选品（还没决定做不做时的第 0 步）：**

`/cm-plugin:scout {商店链接}`——三维评估现存插件值不值得重写：**评论区槽点**（低分评论聚类 = 重写的原始需求，高分评论 = 不能丢的核心体验）、**停更信号**（>6 个月未更新是最强机会信号）、**源码功能盘点**（只盘功能不抄代码，清白室红线）。产出机会评分卡（GO/WATCH/NO-GO 由人拍板）+ 槽点→需求映射表 + 全程 `.log.jsonl` 运行日志（与 /cm-plugin:ai 同规格，可审计）；多次选品由 `SCOUTS.md` 台账串联，WATCH 项带复查到期提醒。GO 后报告直接作为 /cm-plugin:prd 的需求文档。

**存量插件项目：**

1. 在插件项目中运行 `/cm-plugin:init`，生成 `.claude/CLAUDE.md` 和 `rules/` 规范（含 chrome-extension.md 铁律）
2. 建一个 specs 文件夹，把需求文档放进 `docs/`，运行 `/cm-plugin:prd {specs路径}` 生成规格三件套
3. 审查 specs 后运行 `/cm-plugin:ai {specs路径} {插件项目路径}` 开始自动开发
4. 需求变更时用 `/cm-plugin:prd --change {N}.{feature} 变更描述`，已完成任务不受影响

**0 到 1 新插件（无需先手动搭脚手架）：**

1. 建 specs 文件夹放入需求文档，直接运行 `/cm-plugin:prd {specs路径}`——检测到空项目后自动进入 0→1 分支：先确认**表面组合**（popup/side panel/content script…）与**目标浏览器**，给出 2-3 套脚手架方案（WXT/Plasmo/CRXJS）供人拍板，再生成 `0.bootstrap` feature（design.md 即 ADR，任务含脚手架/规范生成/CI 打包/公共底座/E2E 基座）
2. 人审规格（审 `0.bootstrap` 就是审架构，审**权限清单**就是审商店风险）后运行 `/cm-plugin:ai`——bootstrap 完成时的 QA 会把扩展**真实加载进浏览器**截图给你做形态确认
3. 日后架构调整走 `/cm-plugin:prd --change 0.bootstrap 变更描述`，选型演进全程留痕
4. 跳过 `/cm-plugin:init`——空项目没有可分析的对象，规范生成是 bootstrap 的任务之一

**发布：**

feature 全部完成后，N8 会编制**发布待决清单**（版本、权限 diff、商店材料就绪度）；商店提审由你确认后触发，审核状态记入 RELEASES.md，被拒原因按 bug 回流闭环。
