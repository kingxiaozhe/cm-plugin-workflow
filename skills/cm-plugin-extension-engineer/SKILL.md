---
name: cm-plugin-extension-engineer
description: 浏览器扩展工程师 Skill，执行 Chrome 扩展（MV3）开发任务——manifest、service worker、content script、popup/options/side panel、消息通信、chrome.storage，自动适配脚手架（WXT/Plasmo/CRXJS/原生）
---

# cm-plugin-extension-engineer — 浏览器扩展工程师

执行 Chrome 扩展（Manifest V3）开发任务。自动识别项目脚手架与技术栈，遵循项目 `.claude/rules/` 中的规范（`chrome-extension.md` 是本工种铁律）。

## 触发条件

由 `/cm-plugin:ai` 自动调用，当 task 涉及扩展本体开发时触发（manifest / service worker / content script / 各 UI 表面 / 存储 / 消息通信）。

**与 cm-plugin-ui-engineer 的分工**：feature 存在设计基准（design-baseline/）时，popup/options/side panel 的 UI 还原由 `cm-plugin-ui-engineer` 前置完成——本 skill **直接消费其组件与 design.md 组件契约，不重写其样式**；无基准时 UI 按 design.md 自行实现。

**与 cm-plugin-backend-engineer 的分工**：配套服务端（API 代理、账号、同步）归后端工种；本 skill 只写扩展侧的调用层。**API 密钥等机密永远不进扩展包**——扩展包等于公开源码，需要密钥的调用必须走后端代理，发现 design.md 让密钥落在扩展侧时停下上报。

## 工作流程

### 1. 识别脚手架与技术栈

读取项目配置自动判断，不做硬编码假设：

- **脚手架**：`wxt.config.ts` → WXT（entrypoints 目录约定，manifest 由配置生成）；`plasmo` 依赖 → Plasmo（文件名即入口约定）；`@crxjs/vite-plugin` → CRXJS（手写 manifest + Vite）；都没有 → 原生（手写 manifest，注意构建产物路径）
- **manifest 源头**：先弄清 manifest 是手写文件还是构建生成——改错地方（直接改 dist 里的生成物）是脚手架项目最常见的白改
- `package.json` → UI 框架（React/Vue/Svelte/原生）、样式方案、构建工具
- 目标浏览器（CLAUDE.md「交付形态」字段）→ 是否经 webextension-polyfill 调 API、是否有双 manifest 构建

### 2. 读取上下文

- `.claude/rules/chrome-extension.md`、`frontend.md`、`coding-style.md`（如存在）
- design.md 中当前任务相关的模块设计与**消息契约**
- 扫描现有代码，弄清三件事：各表面入口在哪、消息通信封装在哪（有封装必须复用，禁止散落裸调 `chrome.runtime.sendMessage`）、storage 读写层在哪

### 3. 开发

**manifest 纪律（每次触碰都过一遍）：**

- 只声明本任务确需的权限；能用 `activeTab` 就不申请 `host_permissions`，能窄匹配（`*://example.com/*`）就不用 `<all_urls>`
- 新增任何 permission / host_permission → 在任务汇报里写一行用途理由（商店提审要用，人审要看）
- manifest 变更不与业务代码混在一个提交里静默带过，提交信息单独说明

**service worker（MV3 后台）：**

- **它会随时休眠，全局变量必然丢**——跨事件状态一律落 `chrome.storage.session`/`local`，不留内存
- 事件监听器必须在顶层同步注册，不得包在 async 初始化之后（休眠唤醒时只重放顶层注册）
- 没有 DOM——需要解析 DOM/播放音频/用 canvas 时走 offscreen document，用完即关
- 定时任务用 `chrome.alarms`，不用 `setTimeout`/`setInterval`（休眠即失效）

**content script：**

- 运行在 isolated world：与宿主页共享 DOM、不共享 JS 变量；需要读宿主页 JS 状态时注入 main world 脚本并用 postMessage 桥接
- 注入 UI 必须做样式隔离（shadow DOM 优先，或强前缀 class）——宿主页样式什么都可能覆盖你，你也不许污染宿主页
- 宿主页是 SPA 时，URL 变化不触发重新注入——监听路由变化（`Navigation API`/history hook/MutationObserver 择一），初始化要幂等
- 对宿主页 DOM 结构的依赖集中到选择器常量层，宿主页改版时只改一处

**消息通信：**

- 严格按 design.md 消息契约实现（type / payload / 响应结构）；契约没写的消息形状，先补进 design.md 的口径再写码，不各写各的
- 异步响应要 `return true`（callback 风格）或统一用 Promise 风格，一个项目只用一种
- 高频通信（如 devtools/side panel 实时数据）用 `chrome.runtime.connect` 长连接，不高频轮发单次消息

**存储：**

- 分区按用途：`sync`（小体量用户设置，注意 100KB/8KB per-item 配额）、`local`（大数据）、`session`（service worker 临时状态）
- 读写统一走项目的 storage 封装层，schema 变更要写迁移逻辑（老用户的存量数据不会自己变形状）

**UI 表面（popup / options / side panel）：**

- popup 每次打开都是全新页面且失焦即销毁——不在 popup 里放长任务，长任务交 service worker，popup 只读状态
- 组件复用、样式方案、状态管理遵循 frontend.md 与项目既有模式

### 4. 验证

```bash
# 根据项目实际命令执行
npm run lint
npm run typecheck
npm run build
```

**构建产物必须真实加载验证**（扩展的"编译通过"与"能跑"距离极远）：项目有 E2E 基座（Playwright/Puppeteer `--load-extension`）→ 跑冒烟用例；没有 → 至少在本机 Chrome 开发者模式 Load unpacked 一次，确认 manifest 无报错、service worker 注册成功、本任务触碰的表面能打开。加载验证结果写进任务汇报。

## 常见坑

| 问题 | 处理 |
| ---- | ---- |
| service worker 全局变量"莫名"丢失 | 休眠所致，状态迁到 chrome.storage.session |
| 监听器时灵时不灵 | 注册被包进了 async 流程，移到顶层同步注册 |
| content script 读不到宿主页 JS 变量 | isolated world 隔离，注入 main world 脚本桥接 |
| 注入 UI 被宿主页样式打爆 | shadow DOM 包裹，不裸放 DOM |
| SPA 网站切页后功能失效 | 监听路由变化重挂载，初始化写成幂等 |
| sendMessage 响应一直 undefined | 接收端异步未 `return true`，或消息发给了已休眠且无该监听的目标 |
| chrome.storage.sync 写入报配额错 | 超 8KB/item 或 100KB 总量，大数据改 local |
| 改了 manifest 不生效 | 改的是构建生成物；找到源头（wxt.config/plasmo 约定/源 manifest）再改 |
| CSP 报错 eval/远程脚本被拒 | MV3 禁止，改为打包进产物；第三方库依赖 eval 的换库 |
| Firefox 行为不一致 | API 名与回调风格差异，统一走 webextension-polyfill |

## 输出

- 创建/修改的文件列表
- 验证结果（lint + typecheck + build + 真实加载冒烟）
- manifest/权限变更及用途理由（无则写"无"）
- 新增或依赖的消息契约（无则写"无"）
- 需要其他工种配合的事项
