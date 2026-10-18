#!/bin/bash
# Q4：合并日志，按级别提取，保存首尾片段并统计错误行数。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

all="$output/all.log"

# 1) 合并：boot.log 在前，run.log 在后，逐行原样拼接
cat "$input/boot.log" "$input/run.log" > "$all"

# 2) 错误提取：只认行首 "ERROR "；没有匹配是正常输入，
#    grep 此时返回 1，会被 set -e 当成失败，所以要接住
grep "^ERROR " "$all" > "$output/errors.log" || true

# 3) 告警提取：行首是 WARN 或 ERROR 的行
grep -E "^(WARN|ERROR) " "$all" > "$output/attention.log" || true

# 4) 末尾日志：合并结果的最后 5 行（不足 5 行就是全部）
tail -n 5 "$all" > "$output/recent.log"

# 5) 首条错误：错误日志的前 3 行（不足 3 行就是全部）
head -n 3 "$output/errors.log" > "$output/first-errors.log"

# 6) 错误计数：无错误时 grep -c 会输出 0 但返回 1，同样要接住
error_count=$(grep -c "^ERROR " "$all" || true)
printf '%s\n' "$error_count" > "$output/error-count.txt"
