// cm-plugin E2E 冒烟模板 —— bootstrap T-005 拷进 tests/e2e/smoke.spec.ts,把 {占位} 换成本项目实际值。
// 用 extension-harness.ts 封装的健壮底座,不要自己写 launchPersistentContext / SW 获取(会踩全套坑)。
import { test, expect, type BrowserContext, type Worker } from '@playwright/test';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import {
  launchExtension,
  acquireServiceWorker,
  extensionId,
  closeExtension,
} from './extension-harness';

const here = path.dirname(fileURLToPath(import.meta.url));
// {构建产物路径} —— WXT 默认 .output/chrome-mv3;按脚手架实际改
const EXT_PATH = path.resolve(here, '../../.output/chrome-mv3');

let context: BrowserContext;
let swReady: Promise<Worker>;

test.beforeAll(async () => {
  context = await launchExtension(EXT_PATH);
  swReady = acquireServiceWorker(context); // 立即捕获,避开注册-停机竞态
});

test.afterAll(async () => {
  await closeExtension(context); // 带扩展的 context.close() 会挂,用 harness 的超时兜底版
});

test('service worker 注册且 manifest 名称正确', async () => {
  const sw = await swReady;
  expect(sw.url()).toContain('background.js'); // WXT 产物;其他脚手架按实际 SW 文件名
  expect(extensionId(sw)).toMatch(/^[a-z]{32}$/);
  // 标题声称"名称正确"须真断言——读被加载的产物 manifest(N5 运行观察闸:断言要对得上标题)
  const manifest = JSON.parse(fs.readFileSync(path.join(EXT_PATH, 'manifest.json'), 'utf-8'));
  expect(manifest.name).toBe('{扩展名}'); // ← 换成本项目 manifest.name
});

test('popup 能打开', async () => {
  const extId = extensionId(await swReady);
  const page = await context.newPage();
  await page.goto(`chrome-extension://${extId}/popup.html`); // 无 popup 表面则删本用例
  await expect(page.locator('body')).not.toBeEmpty(); // ← 换成本项目 popup 的稳定锚点(如品牌字标)
  await page.close();
});

// ── 真实引擎集成(可选,强烈建议)：起本地 http server 放一个假的目标场景,验证 content script 真处理 ──
// content script 的行为纯单测证不了,只有真实页面能证。参考:
//   import http from 'node:http';
//   起 server 返回带目标元素的 fixture → page.goto → expect.poll 页面状态变化。
//   读 storage 用 wakeServiceWorker(ctx, extId) 取活 SW 再 sw.evaluate(避免 "Worker was closed")。
