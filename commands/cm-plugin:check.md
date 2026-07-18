# /cm-plugin:check — 框架一致性自检

校验 cm 工作流安装的完整性和引用一致性。**每次修改框架文件后运行一次**——历史上的缺陷（改名残留、匹配表缺项、死角色、失效命令引用）全属"引用断链"类，本命令将其机器化检查。

## 检查项

### 1. 角色文件存在性

- `~/.claude/commands/cm-plugin-ai-nodes/N3-execute-task.md` 匹配表中引用的每个 `cm-plugin-*-engineer` / `cm-plugin-*-manager` → `~/.claude/skills/{名称}/SKILL.md` 必须存在
- `N2-enter-feature.md` 预定义角色列表中的每个 `cm-plugin-*-agent` → `~/.claude/agents/{名称}.md` 必须存在
- 反向检查：skills/ 与 agents/ 下存在、但 `~/.claude/commands/` 下**任何文件**（命令 + cm-plugin-ai-nodes/ 节点 + cm-plugin-prd-modes/ 模式文件）均未引用的角色 → 报告为"孤儿角色"（建了没接线）。范围不得收窄到 N2/N3——把关型 skill（cm-plugin-doc-syncer/cm-plugin-product-manager/cm-plugin-qa-engineer/cm-plugin-devops-engineer）按设计接在 cm-plugin:ai/N6/N8/cm-plugin:prd/模式文件上，只查派发路径会把它们误报成孤儿（v0.9.24 实跑教训：init 自举时靠人工甄别才排除三处假阳性）。**检查范围限定 `cm-plugin-` 前缀**——上游 cm-workflow 的 `cm-*` 角色（同机共存时存在）与非前缀独立工具（如 codebase-context）都不参与本检查的角色配对（实跑教训：v0.2.2 首次自测按 cm- 扫会把共存的上游角色误报为孤儿），但其被 cm-plugin:init/cm-plugin:prd/N8 的引用仍走第 3 组命令引用检查

### 2. 命名一致性

- 每个 `skills/*/SKILL.md` 的 frontmatter `name` 必须等于其目录名
- 每个 `agents/*.md` 的 frontmatter `name` 必须等于其文件名（去 .md）
- 全部文件中不得残留旧前缀（如 `yd-`、`yd:`、未改名的 `cm:` 命令引用）；**本条规则自身的示例文本不算残留**（实跑教训：v0.2.2 首次自测 grep 命中本文件的示例即误报）

### 3. 命令间引用有效性

- 所有文件中出现的 `/cm-plugin:{命令}` 引用 → `commands/cm-plugin:{命令}.md` 必须存在
- 所有文件中出现的节点引用（N1–N8）→ `commands/cm-plugin-ai-nodes/` 下对应文件必须存在
- cm-plugin:prd 引用的模式文件 → `commands/cm-plugin-prd-modes/{greenfield,brownfield,change-mode}.md` 三个必须齐全（v0.9.11 拆分产物,缺失即断链）
- skill 之间的互相引用（如"→ cm-plugin-qa-engineer"）→ 目标必须存在

### 4. 配套机制完整性

- agent 与同工种 skill 成对：每个 `cm-X-agent` 必须有其加载的 skill
- README 中的角色计数、目录树条目与实际文件一致
- cm-plugin:prd 任务模板引用的产物（design-baseline、METRICS.md、RELEASES.md）在对应节点/skill 中有生成方
- **rules 引用有生成方**：任何 skill/命令中引用的 `rules/{名称}.md`，必须在 cm-plugin:init 的「规则内容指引」（或 bootstrap 模板）中有对应生成条目——skill 读一个永远不会被生成的规则文件即为断链
- **独立工具 skill 存在性**：cm-plugin:init/cm-plugin:prd/N8 引用了 `codebase-context` → `~/.claude/skills/codebase-context/SKILL.md` 必须存在；缺失报告为断链（旧包安装，提示重装）
- **独立工具 skill 存在性（idea-to-prd）**：cm-plugin:idea 引用 `idea-to-prd` → `~/.claude/skills/idea-to-prd/SKILL.md` 必须存在；缺失同样报断链
- **scout 凭证配对**：cm-plugin:scout 的 GO 对抗确认凭证（`scout-{名}-verdict-r1.md`）↔ 台账中结论为 GO 的行——台账有 GO 而报告目录无 verdict 凭证 → 报告为断链（GO 无对抗凭证 = 单模型自批）
- **凭证/审批位链路配对**：N4 落盘的 `.reviews/` 凭证 ↔ N5 卡点与 N8 对账所引用的路径一致；cm-plugin:prd 写入的 `.cm-specs-status` ↔ N1 入口闸读取的文件名一致——四处引用两两配对（防单边改名断链）
- **规则指引与模板配对**：cm-plugin:init「规则内容指引」中的每个条目 ↔ `~/.claude/templates/cm-plugin-rules/{名称}.md` 模板文件一一对应；缺模板报告为降级项（可运行但生成质量不稳定），多出的孤儿模板报告为未接线
- **流程脚本配对**：命令中引用的每个 `~/.claude/templates/cm-plugin-scripts/{名称}.sh`（preflight/codex/log）↔ 实际脚本文件存在且可执行；缺失报告为降级项（命令会退化为手工执行）。当前引用点：N1 环境预检+Codex 封装、cm-plugin:rewrite R0、cm-plugin:scout 日志助手

### 5. 外部依赖可用性

- **Codex（审查主通道）**：`codex --version` 探测。不可用报告为降级项并给出后果说明——N4 将落到对抗式子代理（次优），N1 开跑前还会再拦一次
- 状态条已配置（settings.json 的 statusLine 指向 cm-plugin-statusline.sh）：未配置报告为提示项（不影响运行，仅少可视化）
- 自动更新器（`~/.cm-plugin-workflow/cm-update.sh` 存在且 settings.json 的 SessionStart 挂载）：未配置报告为提示项（可选；配置后安装一致性由它每会话机械保障,本命令的版本检查退居兜底）
- **安装版本**：读取 `~/.claude/templates/cm-plugin-VERSION` 并显示在结论首行。文件缺失 → 显示"版本: 未知（旧版安装，建议用最新包重装）"——版本混乱是实测踩过的坑，反馈问题必带版本号
- **版本一致性（防混装/旧装）**：本命令文件自带基线号 → **框架版本基线: 0.4.0**（发包时与 VERSION 文件同步递增）。比对规则：
  - 基线 = cm-plugin-VERSION → 一致，正常
  - 基线 ≠ cm-plugin-VERSION 或 cm-plugin-VERSION 缺失 → **报"版本不一致/过旧"并建议重装**："命令文件 v{基线} / 安装标记 v{实际}——本机是混装或旧包，请用最新 zip 重跑 install.sh"（实测事故：公司机器旧包 + 家里新包，功能"消失"排查半天）

## 输出格式

```text
🔍 cm-plugin:check 一致性自检  (安装版本: v{X.Y.Z} / 未知)

角色存在性:   {N} 项检查 · {通过/断链清单}
命名一致性:   {N} 项检查 · {通过/不一致清单}
命令引用:     {N} 项检查 · {通过/失效清单}
配套完整性:   {N} 项检查 · {通过/缺失清单}
外部依赖:     {N} 项检查 · {Codex 可用/降级 · 状态条 已配/未配}
版本一致性:   {一致 v{X.Y.Z} / ⚠ 不一致(命令 v{A} vs 安装标记 v{B}),请重装}

结论: PASSED / {N} 处断链（逐条列出：文件:位置 → 期望 → 实际）
```

发现断链只报告不自动修——修复由人确认后执行。
