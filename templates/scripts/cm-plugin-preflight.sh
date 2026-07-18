#!/usr/bin/env bash
# cm-plugin 环境预检——开跑前一次性探明本机能不能跑 Chrome 扩展开发的全链路。
# 存在理由（实测教训）：/cm-plugin:rewrite 全程最吃时间的不是设计不是逻辑,是环境地雷——
# 系统 Chrome 静默屏蔽 --load-extension、codex 要 --skip-git-repo-check、playwright 浏览器下载被墙。
# 这些报错什么都不给。开跑前跑一遍本脚本,把地雷提前引爆。
# 用法: cm-plugin-preflight.sh   (退出码 0=全通过或仅提示, 1=有阻塞项)
set -uo pipefail

pass(){ printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn(){ printf '  \033[33m⚠\033[0m %s\n' "$1"; WARN=$((WARN+1)); }
fail(){ printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
WARN=0; FAIL=0

echo "🔎 cm-plugin 环境预检"

# 1. Node / npm（脚手架与构建）
if command -v node >/dev/null 2>&1; then
  major=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)
  if [ "${major:-0}" -ge 18 ]; then pass "Node $(node -v)"; else fail "Node 版本过低($(node -v)),需 ≥18"; fi
else fail "Node 未安装（WXT 脚手架/构建依赖）"; fi
command -v npm >/dev/null 2>&1 && pass "npm $(npm -v)" || fail "npm 未安装"

# 2. git（每任务提交/审计链）
command -v git >/dev/null 2>&1 && pass "git $(git --version | awk '{print $3}')" || warn "git 未安装（审计链降级为 NO_GIT）"

# 3. Codex（N4 双模型复审主通道）—— 实测:调用必须带 --skip-git-repo-check
if command -v codex >/dev/null 2>&1; then
  pass "Codex $(codex --version 2>/dev/null | head -1) —— 调用记得带 --skip-git-repo-check --sandbox read-only"
else
  warn "Codex 未装 —— N4 将降级为对抗式子代理(次优)。装: npm i -g @openai/codex"
fi

# 4. 扩展加载能力（最大地雷）—— 系统 Chrome 屏蔽 --load-extension,只有 Chrome for Testing 能加载
CACHE="$HOME/Library/Caches/ms-playwright"
CFT=""
if [ -d "$CACHE" ]; then
  CFT=$(find "$CACHE" -maxdepth 6 -name 'Google Chrome for Testing' -type f 2>/dev/null | head -1)
fi
if [ -n "$CFT" ]; then
  pass "Chrome for Testing 就绪（E2E 用它加载扩展；系统 Chrome 2026 版屏蔽 --load-extension）"
else
  warn "未找到 Chrome for Testing。E2E 无法真实加载扩展。装: npx playwright install chromium"
  echo "     （下载被墙时:改用其他项目已装的 CfT,或本机 Chrome 仅供手动 chrome://extensions 加载）"
fi

# 5. 系统 Chrome（手动形态确认兜底）
if [ -f "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
  pass "系统 Chrome 存在（手动 chrome://extensions 加载可用；自动化用 CfT）"
else
  warn "无系统 Chrome（手动形态确认需要它）"
fi

echo
if [ "$FAIL" -gt 0 ]; then
  echo "结论: $FAIL 项阻塞 / $WARN 项提示 —— 阻塞项先解决再开跑"
  exit 1
else
  echo "结论: 通过（$WARN 项提示,不阻塞）"
  exit 0
fi
