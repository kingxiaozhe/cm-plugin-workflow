#!/usr/bin/env bash
# cm-plugin JSONL 日志助手——让运行日志由工具写,而非手打 bash echo。
# 存在理由（实测教训）：手写 `echo '{...}' >> log` 犯过两类错——先记账后落盘(report_saved 早于文件存在)、
# 攒批导致多条挤同一秒时间线失真。本脚本自动 ISO8601 时间戳、原子追加、事件名非空校验。
# 用法:
#   cm-plugin-log.sh <日志文件> <event> <detail> [k=v ...]
# 例:
#   cm-plugin-log.sh run.jsonl fetch "reviews 页成功" channel=webfetch dim=D1 n=10
# 纪律: 每个事件在其步骤**完成后**立即单独调一次,禁止攒批(每次调用即一次原子追加)。
set -euo pipefail

LOG="${1:?用法: cm-plugin-log.sh <日志文件> <event> <detail> [k=v ...]}"
EVENT="${2:?缺 event}"
DETAIL="${3:?缺 detail}"
shift 3

TS=$(date +%Y-%m-%dT%H:%M:%S%z)

# 用 python 组装 JSON,保证特殊字符(引号/换行/中文)被正确转义——手写 echo 最容易在此翻车
python3 - "$LOG" "$TS" "$EVENT" "$DETAIL" "$@" <<'PY'
import json, sys, os
logfile, ts, event, detail = sys.argv[1:5]
row = {"at": ts, "event": event, "detail": detail}
for kv in sys.argv[5:]:
    if "=" not in kv:
        continue
    k, v = kv.split("=", 1)
    # 数字字段转 int/float,其余留字符串
    if v.lstrip("-").isdigit():
        row[k] = int(v)
    else:
        try:
            row[k] = float(v)
        except ValueError:
            row[k] = v
line = json.dumps(row, ensure_ascii=False)
# 原子追加(单次 write,追加模式)
with open(logfile, "a", encoding="utf-8") as f:
    f.write(line + "\n")
print(line)
PY
