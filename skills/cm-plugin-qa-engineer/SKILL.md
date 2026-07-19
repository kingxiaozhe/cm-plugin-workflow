---
name: cm-plugin-qa-engineer
description: QA 工程师 Skill，执行功能测试、E2E 测试、可视化回归、验收标准核验，自动适配项目测试框架
---

# cm-plugin-qa-engineer — QA 工程师

在开发任务完成后执行整体质量验证。自动识别项目测试框架。

## 触发条件

由 `/cm-plugin:ai` 自动调用，当 task 涉及测试或全部开发完成后触发。

## 工作流程

### 1. 识别测试框架

自动检测，不做硬编码假设：

- **单元/组件测试**：Vitest / Jest / Mocha（`chrome.*` API 在单测里用 mock 层——检查项目是否已有统一 mock，没有则建一个共享的，禁止每个测试文件各 mock 各的）
- **E2E 测试（扩展专用姿势）**：**优先用 `~/.claude/templates/cm-plugin-e2e/extension-harness.ts` 封装的底座**（bootstrap T-005 应已拷入 `tests/e2e/`）——它把五个实测坑封装好了：系统 Chrome 屏蔽 `--load-extension`（须 Chrome for Testing）、`--headless=new`（旧 headless 不支持扩展、`headless:false` 无头环境退化）、SW 注册-停机竞态（`acquireServiceWorker` 三路取先到）、`sw.evaluate` 前须 `wakeServiceWorker` 取活引用（否则 "Worker was closed"）、CfT 跨架构路径。**别自己手写 `launchPersistentContext`**，会重踩。popup 用 `chrome-extension://{id}/popup.html` 直开断言。项目无 harness（旧包/非 bootstrap 建）→ 从模板补建
- **覆盖率工具**：c8 / istanbul
- 如项目未配置测试框架，根据技术栈推荐并安装（E2E 基座应由 bootstrap T-005 建好，缺失时补建并记 LESSONS）

### 2. 读取上下文

- requirements.md 中的验收标准
- design.md 了解功能模块和接口契约
- `.claude/rules/testing.md`（如存在）
- 扫描现有测试文件了解测试模式和覆盖情况

### 3. 补全测试

对开发阶段未写测试的代码补充：

- **组件**：渲染测试、交互测试、Props 边界
- **消息通信层**：每个消息 type 的正常流/异常 payload/无响应超时——契约是扩展的接口，测它等于测 API
- **存储层**：chrome.storage 读写封装、schema 迁移逻辑（老数据形状喂进去不炸）
- **service worker 生命周期**：关键状态在"休眠丢内存"前提下仍正确（测试里主动清内存态模拟唤醒）
- **content script**：注入幂等（重复注入不重复挂 UI）、目标站点 DOM 选择器仍命中（选择器层单独可测）
- **工具函数**：输入输出覆盖
- **配套后端**（如有）：API 正常流、异常流、migration 可执行

遵循项目已有的测试文件命名和目录约定。

**二开回归范围跟波及面走**：design.md 存在「波及面」段时，回归测试范围 = 新功能 AC + 波及面清单上的存量功能逐项冒烟——新功能好不好是一半，老功能没坏才是另一半。

**禁止前提共谋（硬规则）**：断言含具体数值时，测试输入必须**多参数化**（至少覆盖 2-3 组不同前提），禁止测试与被测代码共享同一默认前提——硬编码值在唯一被测前提下"恰好成立"是已实证的盲区模式（实跑教训：断言与配置都默认 A4，切 A5 即错位 39.9mm，参数化后现形）。

### 4. 运行测试

```bash
# 根据项目实际命令执行
npm run test              # 或 pnpm test / cargo test / pytest
npm run test -- --coverage  # 覆盖率
npx playwright test       # E2E
```

收集：通过数/失败数/覆盖率。

### 5. 可视化回归（如涉及 UI）

1. 以 `--load-extension` 启动加载构建产物的浏览器（popup/options/side panel 在扩展上下文里截，content script UI 在真实目标页面上截；不用脱离扩展上下文的 dev server 页面充数）
2. 选择浏览器驱动（按优先级）：
   - **检查项目配置**：如 `.claude/rules/testing.md` 中指定了 `browser_driver`，使用用户指定的方式
   - **默认：Playwright CDP（无头模式）** — 不弹窗，适合截图对比、DOM 断言、样式回归等大多数场景
   - **自动升级：Chrome DevTools MCP** — 当检测到以下场景时切换：需要登录态/Cookie 持久化、OAuth/第三方弹窗交互、需要观察真实动画/过渡效果、用户明确要求实时调试
   - 切换前输出：`🔄 切换到 Chrome DevTools MCP — 原因: {原因}，浏览器窗口将弹出`
3. 截图保存
4. 对比基准截图（如有）

> **用户覆盖**：在 `.claude/rules/testing.md` 中添加 `browser_driver: playwright | chrome-mcp | ask` 可固定选择或设为每次询问。

### 6. 验收标准核验

逐条检查 requirements.md 中的验收标准：

```markdown
- [x] [AC-001] 描述 → 已通过测试验证
- [ ] [AC-002] 描述 → ⚠️ 需手动验证
```

标注每条的验证方式（自动/手动/无法自动化）。

**核验结果必须回写 requirements.md 的验收标准 checkbox**（`[x] [AC-001] → 已通过测试验证`），不得只留在会话输出中——验收状态和任务状态一样落盘。

### 6.5 商店合规检查单（涉及权限/数据收集/远程内容的 feature 必跑）

被 N6 走查、/cm-plugin:prd 预扫或 devops 发布前自查引用时，逐项核对并输出结论（**把关型检查：只举旗列清单，不自行定性"能过审"**）。

**检测方法（机器优先，肉眼兜底）**：先按 `references/cws-scan-checklist.md` 跑 grep 检测模式（12 类风险，源自 MIT 收编素材，见 NOTICE.md；模式里的 `src/` 路径按项目实际结构替换——WXT 是 `entrypoints/`，Plasmo 是根目录约定，manifest 按构建产物扫）；命中项的严重级与官方违规码对照 `references/cws-violation-codes.md`（CRITICAL=必拒 / HIGH=大概率拒 / MEDIUM=可能拒），举旗时带上违规码名（如 Purple Potassium），被拒申诉时能直接对上 Chrome 的拒审邮件。

人工核对项：

- [ ] **权限最小化**：manifest 中每个 permission / host_permission 都能对到一个已实现功能；有对不上的 → 举旗"冗余权限"
- [ ] **单一用途**：本次 feature 与扩展声明的单一用途描述一致；功能开始发散（工具箱化）→ 举旗
- [ ] **数据披露**：实际收集/传输的用户数据（浏览记录、页面内容、表单输入、身份信息）逐项在隐私政策与商店数据披露表覆盖；代码里传了政策里没写的 → 举旗
- [ ] **禁远程代码**：无 eval / new Function / 远程加载执行的 JS（远程取配置、取数据可以，取可执行代码不行）
- [ ] **内容注入克制**：content script 的 matches 范围与功能必要性一致；未经用户触发的页面改写、广告注入类行为 → 举旗
- 结论固定格式：`商店合规: 通过 / {N} 项举旗（逐条: 检查项[违规码] → 证据位置 → 建议）`，举旗项由主流程交人裁决

### 7. 处理失败

- 测试失败 → 判断是代码 bug 还是测试问题
- 代码 bug → 汇报给主 agent，重新执行开发任务
- 测试问题 → 修复测试，重新运行
- 最多重试 3 轮

## 常见坑

| 问题                     | 处理                                   |
| ------------------------ | -------------------------------------- |
| 测试环境和开发环境不一致 | 检查 test 配置中的环境变量和 mock 设置 |
| 异步测试超时             | 增加 timeout，检查是否缺少 await       |
| E2E 测试不稳定（flaky）  | 用 `waitFor` 代替固定延时，重试机制    |
| 覆盖率统计不准           | 检查 coverage 配置的 include/exclude   |
| E2E 里扩展没加载         | 系统 Chrome 屏蔽 --load-extension → 用 Chrome for Testing + `--headless=new`（harness 已封装） |
| E2E 时好时坏(flaky)      | 多因 `headless:false` 在无头/CI 退化 或 SW 停机竞态——改用 harness 的 `--headless=new` + `acquireServiceWorker` |
| sw.evaluate "Worker was closed" | SW 已 idle 停机——用 `wakeServiceWorker(ctx, extId)` 取活引用再 evaluate |
| service worker 取不到    | 它可能已休眠——先触发一次扩展事件唤醒再 `serviceWorkers()` |
| chrome.* mock 行为与真实不符 | mock 只兜单测；行为断言以 E2E 真实浏览器为准，两层结论冲突时信 E2E |

## 输出

```text
📋 QA 报告

测试: {N} 通过 / {N} 失败 / 覆盖率 {N}%
E2E: {状态}（真实浏览器加载扩展）
验收标准: {N}/{total} 通过, {N} 需手动验证
商店合规: {通过 / N 项举旗 / 未触发}
安全扫描: {状态}
结论: {PASSED / FAILED / NEEDS_MANUAL}
```
