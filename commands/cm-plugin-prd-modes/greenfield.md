# cm-plugin:prd 模式文件 — 0→1 空项目分支（GREENFIELD）

> 由 /cm-plugin:prd Step 3 判定 GREENFIELD=true 时读取本文件。规则内容与主文件同源拆分,语义未变。

## 0→1 空项目分支（GREENFIELD）

Step 3 检测到 `GREENFIELD=true` 时叠加以下规则。核心思想：**架构决策也是需求的产物，走同一条 specs 流水线**——选型即设计，搭建即任务，享受同样的人审卡点、断点恢复和审计链。

### G1: 技术选型确认（并入 Step 5.5）

**先读完需求再谈选型，推荐必须从需求特征推导，不套通用默认。** 流程：

0. **交付表面必问（第一问，不可默认）**：本工作流交付形态固定为**浏览器扩展（MV3）**，但表面组合是架构第一分叉：popup / options / side panel / content script / devtools 面板 / 新标签页接管 / 纯后台——需求没写就必须问，答案强制写入 ADR 和 CLAUDE.md 的「交付形态」字段（如 `Chrome 扩展 · side panel + content script`）。同时必问**目标浏览器**：仅 Chrome / Chrome+Edge / 含 Firefox（决定是否引入 webextension-polyfill 与双 manifest）。**需求方说"做个插件"时脑中的画面千差万别，表面组合看错全错**
1. **联网校验当前最佳实践**：确认表面组合后，WebSearch 当年扩展脚手架生态（WXT / Plasmo / CRXJS 迭代和维护状态变化快，不可凭记忆推荐）；网络不可用 → 使用 `~/.claude/templates/cm-plugin-arch-reference.md` 基准表兜底，并向用户标注快照日期建议复核；联网发现基准表过时 → 顺手更新它
2. **提取需求特征**并给出架构含义（展示推导过程，让人能审）：

```text
需求特征 → 架构含义（示例）
- 改写/增强特定网站页面   → content script 为主,注意 isolated world 与宿主样式隔离
- 常驻工具面板            → side panel(Chrome 114+) 优于 popup(点开即关)
- 拦截/改写网络请求       → declarativeNetRequest(注意规则上限),MV3 已无 blocking webRequest
- 需要账号/跨设备同步     → chrome.storage.sync 够小数据;大数据/多端 → 配套后端
- 调用 AI/付费 API        → 密钥不得进扩展包,必须配套后端代理
- 需要抓取/解析页面数据   → content script 提取 + service worker 汇总,注意宿主页 SPA 路由变化
- 多浏览器发布            → webextension-polyfill + 构建期双 manifest
- 团队约束/发布条件       → 一票否决项,压过所有技术偏好
```

3. 基于特征给出 **2-3 套定制方案**，每套包含：脚手架（WXT / Plasmo / CRXJS+Vite / 原生无框架）、UI 技术栈、取舍、**对应的脚手架命令**（如 `npx wxt@latest init`、`npm create plasmo`、`npm create vite@latest -- --template react-ts` + CRXJS），并标注推荐项及推导理由（含联网校验的来源）。**命令验证边界：只许 `--help` 核实参数、`--dry-run` 验证组合，不得实际生成项目**——生成是 T-001 的职责，G1 阶段生成会让 N1 撞上"目录非空 + T-001 未勾选"信号，凭空多一次人工确认（实测教训）
4. 人做选择题，不做填空题；确认结果连同脚手架命令写入 ADR，bootstrap T-001 直接使用该命令。**写入 ADR 的必须是全参数命令**（含包管理器等全部选项）——缺参数的命令会在无人值守执行时停下来交互式提问；现代脚手架（如 better-t-stack）完成/dry-run 时会回显"可复现完整命令"，抄它进 ADR 是标准做法

必须覆盖的提问维度：

- 团队已熟悉的技术栈（这是约束，不是偏好）
- 发布渠道（Chrome Web Store 公开上架 / unlisted / 企业内部分发 / 仅开发者模式自用——决定合规投入的量级）
- 是否需要配套后端（账号体系、API 代理、数据同步；纯本地插件可以零后端）
- 版本控制（默认本地 git init，写成"默认 X 如不符请指出"；用户明确不用 → bootstrap 的 CLAUDE.md 版本控制字段记 `none`，全链路降级）
- 权限敏感度（目标用户对 host_permissions 范围的接受度；`<all_urls>` 会显著拉长商店审核并吓退用户）

**选型未确认前不得进入 Step 6。**

### G2: 生成 0.bootstrap feature（在业务 feature 之前）

编号固定为 `0`，业务 feature 从 `1` 开始：

```text
{SPECS_DIR}/
├── docs/
├── 0.bootstrap/          ← 0→1 专属
│   ├── requirements.md   # 非功能需求：团队约束、部署条件、性能要求、预算
│   ├── design.md         # 即 ADR：候选方案对比表、最终选型、每项理由
│   └── tasks.md          # 见下方任务模板
└── 1.{business-feature}/
```

`design.md` 按 ADR（架构决策记录）写：候选方案对比表（方案 / 优势 / 代价 / 是否入选）+ 最终选型清单 + 每项决策的理由。**这份文件就是日后回答"当时为什么选 X"的唯一出处。**

`tasks.md` 任务模板（按需裁剪）：

```markdown
- [ ] T-001: 用选定脚手架生成扩展骨架（{选定的 create 命令}），manifest 只声明本期确需的最小权限；脚手架未自带 git 时执行 git init ~15min
- [ ] T-002: 生成 .claude/ 规范（等同 /cm-plugin:init 产出，基于已选型技术栈，必含 rules/chrome-extension.md） ~15min
- [ ] T-003: CI 与构建骨架（lint/test/build 流水线 + 打包 zip 产物，环境变量模板） ~30min ——**计划迭代 ≥3 个 feature 的项目不得裁剪本任务**：测试是基建不是环节，第一周省下的半小时会在第五周连本带利还（实测两次 demo 裁剪 + 行业重度实践共同教训）
- [ ] T-004: 公共底座（消息通信封装、chrome.storage 读写层、错误处理、各表面入口结构） ~30min
- [ ] T-005: E2E 基座（Playwright/Puppeteer 以 --load-extension 启动真实浏览器加载构建产物，跑通一条"扩展能加载、service worker 能注册"的冒烟用例） ~30min ——扩展的"能跑起来"只能在真实浏览器里验证，这条冒烟是 N6 形态确认卡点的技术前提
```

### G3: 业务 feature 的生成规则

业务 feature 的 design.md 基于 **G1 已确认的选型**生成（此时规范文件尚不存在，以选型结论为准）。执行时序由 /cm-plugin:ai 保证：`0.bootstrap` 最优先执行，完成后规范已落地，后续 feature 加载的就是真实的 CLAUDE.md 和 rules。

### G4: 后续架构变更

架构调整走已有变更模式：`/cm-plugin:prd --change 0.bootstrap 数据库从 SQLite 换 Postgres`——ADR 追加版本行，决策演进全程留痕。

**执行中发现架构错配的标准处置**（如 /cm-plugin:ai 跑到一半发现交付形态/框架不对）：

1. **干净停点**：当前任务走完 N5（标记+落盘）再停
2. **形态确认与回收率评估**（先问清目标形态再动手）：换脚手架（如 Plasmo → WXT）≈80% 可回收（业务逻辑与 UI 组件可迁，入口与构建配置重写）/ 换表面（如 popup → side panel）≈90%（改入口与 manifest）/ 从扩展改成 Web 应用或反向 ≈30%（`chrome.*` 依赖层全部重写，只有纯逻辑与 specs 可复用）
3. `/cm-plugin:prd --change 0.bootstrap 交付形态从 X 改为 Y` → ADR 记 v2，受影响任务标 `[DROPPED]`/`[NEW]`（含显式迁移任务），已完成可保留的不动
4. **旧代码移入 `legacy/`**，可回收部分由迁移任务显式搬运；重跑 /cm-plugin:ai 时 N1 的目录信号会强制确认目录处置
5. 断点恢复按新标记续跑
