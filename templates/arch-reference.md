# 扩展架构基准参考表（快照日期: 2026-07 · G1 使用时必须联网校验刷新）

> 本表是**离线兜底基准**,不是权威答案。G1 推荐架构前应 WebSearch 扩展脚手架生态的当年状态;
> 网络不可用时才直接使用本表,且必须向用户标注"基于 2026-07 快照,建议联网复核"。

## 扩展脚手架

| 场景 | 推荐 | 脚手架命令 | 依据 |
| ---- | ---- | ---- | ---- |
| 大多数新项目 | **WXT** | `npx wxt@latest init` | 约定式 entrypoints、HMR 完善、跨浏览器构建（Chrome/Firefox 双产物）与 `wxt zip`/自动发布链路齐全,社区活跃度 2026 领先 |
| React 重 UI、偏好文件约定 | Plasmo | `npm create plasmo` | 文件名即入口,上手快;注意 2024 后维护节奏放缓,选用前联网核实状态 |
| 想完全掌控 Vite 配置 | CRXJS + Vite | `npm create vite@latest` + `@crxjs/vite-plugin` | 手写 manifest,最透明;配置成本自担 |
| 无构建极简插件(几个文件) | 原生无框架 | 手写 manifest.json | 零依赖;超过 3 个源文件就不值得 |

UI 层惯配: React/Vue 任选 + Tailwind CSS;与团队既有栈一致优先。

## 表面选择

| 需求 | 表面 | 备注 |
| ---- | ---- | ---- |
| 点击即用的轻交互 | popup | 失焦即销毁,不放长任务 |
| 常驻工具面板 | side panel | Chrome 114+;Firefox 用 sidebar_action,跨浏览器需适配 |
| 改写/增强特定网站 | content script | isolated world + shadow DOM 隔离 |
| 全局设置页 | options page | |
| 调试/开发者工具类 | devtools panel | |
| 替换新标签页 | chrome_url_overrides | 商店审核对此类更严格 |

## 配套后端（仅在需要账号/同步/密钥代理时引入）

| 场景 | 推荐 | 依据 |
| ---- | ---- | ---- |
| TS 团队/轻量代理层 | **Hono / Fastify**（可部署 Cloudflare Workers） | 扩展后端多为薄代理,edge 部署延迟低免运维 |
| 快速起量/免运维 | Supabase / Firebase(BaaS) | 自带鉴权,注意锁定成本 |
| 无账号无密钥需求 | **不建后端** | chrome.storage 足够;别为架构完整性凑后端 |

扩展侧鉴权注意：无传统 cookie 会话,用 token（chrome.storage 存储 + 后端校验）;CORS 允许来源写 `chrome-extension://{id}`。

## 跨浏览器

| 目标 | 方案 |
| ---- | ---- |
| 仅 Chrome/Edge | 直接用 `chrome.*`(MV3) |
| 含 Firefox | webextension-polyfill + 构建期双 manifest（WXT 原生支持）;side panel/declarativeNetRequest 等差异 API 逐项确认 |
| 含 Safari | `safari-web-extension-converter` 转换 + Xcode 打包,成本显著,默认不承诺 |

## 测试与发布工具链（推荐时一并写入 ADR）

- E2E = Playwright `launchPersistentContext` + `--load-extension`（扩展不能用默认无头远程浏览器）
- UI 验收 = BackstopJS（popup/options/side panel 均为浏览器可渲染表面）
- 发布 = 脚手架打包命令出 zip + Chrome Web Store 提审;CI 自动上传可用 `chrome-webstore-upload-cli`（联网核实维护状态）

## 维护规则

- 本表由 G1 联网校验结果**顺手更新**（发现快照过时 → 更新表格与快照日期,是 doc-syncer 职责的延伸）
- 表中"推荐"永远让位于 G1 的两条一票否决：团队约束、发布条件
