// cm-plugin E2E harness —— MV3 扩展 Playwright 测试的久经考验底座。
// 这套代码封装的每一条都是 dogfood 实测踩出来的坑,新插件直接拷进 tests/e2e/ 用,别重踩。
// 依赖: @playwright/test。适配 WXT 构建产物(.output/{browser}-mv3)。
//
// 为什么要有它(五个坑,散文记不住,代码才靠得住):
//   1. 系统 Chrome(2026 版)默认屏蔽 --load-extension → 扩展静默不加载,SW 永不注册。只有 Chrome for Testing 能加载。
//   2. headless:false 依赖真实显示,在无头 shell / CI 里退化 flaky → 用 --headless=new(新无头支持 MV3 扩展)。
//   3. SW 从 onInstalled 注册后会很快 idle 停机 → 事后 serviceWorkers() 为空且 waitForEvent 等不到新事件,竞态。
//   4. 复用旧 SW 引用做 evaluate → "Worker was closed"。要用前唤醒取活引用。
//   5. CfT 路径随架构/OS 变(mac-arm64/mac-x64/linux),且多缓存版本要选最新。

import { chromium, type BrowserContext, type Worker } from '@playwright/test';
import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';

/** 跨架构/OS 发现 playwright 缓存的 Chrome for Testing 二进制,按版本降序选最新。找不到返回 undefined(调用方回退 channel)。 */
export function resolveChromeForTesting(): string | undefined {
  const cache =
    process.env.PLAYWRIGHT_BROWSERS_PATH ||
    (process.platform === 'darwin'
      ? path.join(os.homedir(), 'Library/Caches/ms-playwright')
      : process.platform === 'win32'
        ? path.join(os.homedir(), 'AppData/Local/ms-playwright')
        : path.join(os.homedir(), '.cache/ms-playwright'));
  if (!fs.existsSync(cache)) return undefined;
  const layouts = [
    'chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing',
    'chrome-mac-x64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing',
    'chrome-linux/chrome',
    'chrome-win/chrome.exe',
  ];
  const dirs = fs
    .readdirSync(cache)
    .filter((d) => d.startsWith('chromium-'))
    .sort((a, b) => Number(b.split('-')[1] || 0) - Number(a.split('-')[1] || 0)); // 版本降序
  for (const dir of dirs) {
    for (const layout of layouts) {
      const p = path.join(cache, dir, layout);
      if (fs.existsSync(p)) return p;
    }
  }
  return undefined;
}

/** 用 CfT + --headless=new 加载解包扩展。extPath 指向构建产物目录(含 manifest.json)。 */
export async function launchExtension(extPath: string): Promise<BrowserContext> {
  if (!fs.existsSync(path.join(extPath, 'manifest.json'))) {
    throw new Error(`扩展产物缺失: ${extPath}/manifest.json —— 先跑 build`);
  }
  const executablePath = resolveChromeForTesting();
  return chromium.launchPersistentContext('', {
    ...(executablePath ? { executablePath } : { channel: 'chromium' }),
    headless: true,
    args: [
      '--headless=new', // 新无头模式支持 MV3 扩展(旧 headless 不支持,headless:false 无头环境退化)
      `--disable-extensions-except=${extPath}`,
      `--load-extension=${extPath}`,
    ],
  });
}

/** 取 SW 引用:已存在 / 新注册事件 / 轮询已注册(含停机的) 三路取先到,彻底避开注册-停机竞态。 */
export function acquireServiceWorker(ctx: BrowserContext, timeoutMs = 12_000): Promise<Worker> {
  const now = ctx.serviceWorkers();
  if (now[0]) return Promise.resolve(now[0]);
  const byEvent = ctx.waitForEvent('serviceworker');
  const byPoll = (async () => {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      const [sw] = ctx.serviceWorkers();
      if (sw) return sw;
      await new Promise((r) => setTimeout(r, 200));
    }
    throw new Error('service worker 未在超时内注册');
  })();
  return Promise.race([byEvent, byPoll]);
}

/** 从 SW url 取扩展 id(32 位小写)。 */
export function extensionId(sw: Worker): string {
  return new URL(sw.url()).host;
}

/**
 * 唤醒并取"活的"SW,再做 sw.evaluate。SW 会 idle 停机,复用旧引用 evaluate 会 "Worker was closed"——
 * 本函数先开一个扩展页触发 SW 启动,再取活引用。凡 sw.evaluate(读 storage 等)前都用它。
 */
export async function wakeServiceWorker(ctx: BrowserContext, extId: string): Promise<Worker> {
  const ping = await ctx.newPage();
  await ping.goto(`chrome-extension://${extId}/manifest.json`).catch(() => {});
  const sw = await acquireServiceWorker(ctx);
  await ping.close();
  return sw;
}

/**
 * afterAll 里关闭 context。dogfood 实测:带扩展的 persistent context `ctx.close()` 会挂 30s 超时
 * (扩展 SW/浏览器进程收尾卡住),afterAll 超时且进程残留累积 → 后续测试环境退化 flaky。
 * 本函数先关所有页,再 close() 但用超时兜底(race)——超时就放手,残留进程由 playwright teardown/OS 收。
 * 用法: `test.afterAll(() => closeExtension(context))`。
 */
export async function closeExtension(ctx: BrowserContext | undefined, timeoutMs = 5000): Promise<void> {
  if (!ctx) return;
  for (const p of ctx.pages()) await p.close().catch(() => {});
  await Promise.race([
    ctx.close().catch(() => {}),
    new Promise<void>((r) => setTimeout(r, timeoutMs)),
  ]);
}
