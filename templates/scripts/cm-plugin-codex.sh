#!/usr/bin/env bash
# cm-plugin Codex 审查封装——一处收齐 codex exec 的正确调用姿势 + 输出清洗 + 凭证落盘。
# 存在理由（实测教训）：全程调 codex 十几次,每次都要记得 --skip-git-repo-check --sandbox read-only、
# 手动加超时、再 tail 清洗它探索源码的 stdout 转储才拿到结论。本脚本一把封装。
# 用法:
#   cm-plugin-codex.sh "<提示词>" [凭证落盘路径]
#   echo "<提示词>" | cm-plugin-codex.sh - [凭证落盘路径]
# 输出: 清洗后的 Codex 结论到 stdout；给了凭证路径则同时 tee 落盘(N4/prd/scout 凭证纪律)。
# 退出码: 0=拿到结论, 2=codex 未装(调用方按降级链处理)。
set -uo pipefail

PROMPT="${1:?用法: cm-plugin-codex.sh \"<提示词>\" [凭证路径]}"
CRED="${2:-}"
TIMEOUT="${CM_CODEX_TIMEOUT:-480}"

if [ "$PROMPT" = "-" ]; then PROMPT=$(cat); fi

if ! command -v codex >/dev/null 2>&1; then
  echo "codex 未安装——按 N4 三级降级链处理(对抗式子代理/核验类自审)" >&2
  exit 2
fi

# 正确调用姿势封装:read-only 沙箱 + 跳过 git 检查 + 从 stdin 关闭交互 + 超时。
# 超时用「输出落临时文件 + 轮询 PID」实现——把 codex 后台化再 $() 捕获会丢输出(实测踩过),
# 落文件最稳,且 macOS 无 GNU timeout 也能跑。
TMP=$(mktemp)
codex exec --skip-git-repo-check --sandbox read-only "$PROMPT" </dev/null >"$TMP" 2>&1 &
CODEX_PID=$!
i=0
while kill -0 "$CODEX_PID" 2>/dev/null; do
  i=$((i+1))
  [ "$i" -ge "$TIMEOUT" ] && { kill "$CODEX_PID" 2>/dev/null; echo "(codex 超时 ${TIMEOUT}s,已终止)" >>"$TMP"; break; }
  sleep 1
done
wait "$CODEX_PID" 2>/dev/null || true
RAW=$(cat "$TMP"); rm -f "$TMP"

# 输出清洗:codex 常把探索源码的过程转储进 stdout,真正结论在末尾 "tokens used" 之前。
# ① 去掉 tokens 计数行 ② 去掉已知噪音(stdin 提示/codex 标记/提示词回显) ③ 取末段。
CLEAN=$(printf '%s\n' "$RAW" | grep -vxF "$PROMPT" | grep -vE '^(codex|user|Reading additional input.*|tokens used|[0-9,]+|\(codex 超时.*|OpenAI Codex .*|-{3,}|workdir:.*|model:.*|provider:.*|approval:.*|sandbox:.*|reasoning .*|session id:.*)$' | awk '
  { buf = buf $0 "\n" }
  END {
    n = split(buf, lines, "\n")
    start = n - 20; if (start < 1) start = 1
    for (i = start; i <= n; i++) if (lines[i] != "") print lines[i]
  }')
[ -z "$CLEAN" ] && CLEAN=$(printf '%s\n' "$RAW" | tail -15)

if [ -n "$CRED" ]; then
  { echo "# Codex 审查凭证 · $(date +%Y-%m-%dT%H:%M:%S%z)"; echo; printf '%s\n' "$CLEAN"; } > "$CRED"
fi
printf '%s\n' "$CLEAN"
