---
description: {一句话：浏览器扩展（MV3）开发铁律——权限、后台、注入、存储、发布}
globs: {如 "src/**", "entrypoints/**"，按脚手架实际目录}
---

<!-- 模板骨架 · 生成时遵守四原则，{占位符} 结合项目填充 -->

# 浏览器扩展规范

## 项目形态（生成时填死，变更过人工确认）

- 脚手架: {WXT / Plasmo / CRXJS+Vite / 原生}；manifest 源头: {wxt.config.ts / 文件约定 / 手写 manifest.json 路径}
- 表面组合: {popup / options / side panel / content script / devtools}
- 目标浏览器: {仅 Chrome / Chrome+Edge / 含 Firefox（经 webextension-polyfill）}

## 权限（最大红线）

- manifest 中每个 permission / host_permission 必须能对到一个已实现功能；**新增权限 = 契约变更**，提交信息单独说明并附用途理由，不与业务代码混提
- 能用 `activeTab` 不申请 host_permissions；能窄匹配不用 `<all_urls>`

  ```jsonc
  // Bad：为"读当前页标题"申请全站常驻权限
  "host_permissions": ["<all_urls>"]
  // Good：用户点击触发的读取用 activeTab 即可
  "permissions": ["activeTab"]
  ```

- 禁止 eval / new Function / 远程加载可执行代码（MV3 CSP 硬约束，也是商店红线）；远程只取数据，不取代码
- API 密钥不进扩展包（扩展包=公开源码）——需要密钥的调用走 {后端代理地址/方案}

## service worker（后台）

- **会随时休眠**：跨事件状态一律落 `chrome.storage.{session/local}`，禁止依赖全局变量存活
- 事件监听器顶层同步注册，不包进 async 初始化
- 定时用 `chrome.alarms`，禁止 `setTimeout` 跨事件计时；DOM/canvas/音频需求走 offscreen document

## content script

- 注入 UI 一律 {shadow DOM / 前缀方案}——不裸放 DOM、不污染宿主页样式
- 宿主页 DOM 选择器集中在 {选择器常量文件路径}，禁止散落在业务逻辑里
- 初始化必须幂等（SPA 路由变化会重复触发）；宿主页 JS 状态需经 main world 桥接，不假装 isolated world 能直接读

## 消息与存储

- 消息契约（type/payload/响应）集中定义在 {契约文件路径}，收发都走 {封装层路径}，禁止裸调 `chrome.runtime.sendMessage`
- 异步响应风格统一为 {Promise / return true 回调}（二选一，全项目一致）
- storage 分区约定：sync = {用户设置类}，local = {大数据类}，session = {SW 临时态}；schema 变更必须附迁移逻辑（老用户数据不会自己变形状）

## 构建与发布

- 版本号唯一源: {package.json / manifest}，发布前必递增
- 打包命令: {npx wxt zip 等实际命令}；产物加载冒烟后才算构建通过（编译过 ≠ 能跑）
- manifest 变更、权限 diff 在 PR/提交描述中显式列出
