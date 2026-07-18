# N3: 执行 Task

## 开始标记

```text
🔨 Task {T-编号}: {任务描述} ~{预估时间}
   Feature {F}/{总F} | 任务 {N}/{总数}
```

## Skill 匹配

根据任务涉及的工种，查看可用的 `cm-plugin-*` skills：

- 插件本体（manifest / service worker / content script / popup / options / side panel / chrome.storage / 消息通信） → `cm-plugin-extension-engineer`
- UI 还原（有 design-baseline 的 popup/options/side panel 界面） → `cm-plugin-ui-engineer`
- 配套后端 API（同步、鉴权、AI 代理等服务端） → `cm-plugin-backend-engineer`
- QA/测试 → `cm-plugin-qa-engineer`
- 打包/发布（Chrome Web Store 提审、版本管理） → `cm-plugin-devops-engineer`
- 没有匹配 → AI 直接执行

有匹配的 skill → 调用该 skill 执行。

**串行 / 并行的执行方式**：串行任务由主 agent 直接按 skill 执行；并行任务（由 N2 计划决定）派发对应的 `cm-*-agent` 子 agent，agent 内部加载同名工种 skill。两种方式的产出都必须回到 N4 走审查。

## 开发

- 参考 design.md 技术设计和 `.claude/rules/` 规范
- 技术选型自行选最优解，不暂停
- 业务逻辑歧义按需求最合理解释执行并显式记录假设；**仅灾难级**（不可逆破坏/资金密钥合规/形态级错向）暂停——见 cm-plugin:ai 全局规则
- **依赖与工具链纪律**：新引入的依赖/构建工具必须**钉版本写进 manifest**（dependencies/devDependencies），禁止在脚本里临时 `npx` 拉 latest（不可复现，锁网 CI 直接挂）；工具链改动在提交信息中单独说明，不静默混入功能变更（实跑教训：防护网脚本裸 npx esbuild 被复审抓出）
- **二开范围纪律：只改任务范围内的代码，禁止顺手重构**——顺手"优化"老代码是存量项目的事故之源；想重构的记入 LESSONS 待触发备忘，事后走 `/cm-plugin:refactor` 单独立项、单独审查，不许夹带。改老文件跟老文件风格走，新文件才按新规范写
- **平台专属 API 首次引入必查社区已知问题**（WebSearch"{API 名} 已知问题/踩坑"）：`chrome.*` 扩展 API 的不可靠组合官方文档不会写——MV3 service worker 休眠丢状态、offscreen document 生命周期、declarativeNetRequest 规则上限、跨浏览器 API 差异都是社区长期报告的重灾区。查证结论一行留在任务汇报里
