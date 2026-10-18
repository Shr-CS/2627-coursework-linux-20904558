#!/bin/bash
# Bonus：start 时创建分离的 tmux 会话和采集器；stop 时正常停止采集器并结束会话。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

action=${3:-start}

# 教师为本次场景生成的 tmux 参数
source "$input/bonus.env"

log="$output/bonus.log"

if [ "$action" = "start" ]; then
    # -d 创建分离会话：脚本返回后会话仍然存在，采集器继续写日志。
    # 路径可能含空格，先逐个引用好再交给 tmux 的 sh -c。
    : > "$log"
    worker="exec python3 $(printf '%q' "$WORKER_TOOL") --token $(printf '%q' "$TOKEN") --log $(printf '%q' "$log")"
    tmux -L "$TMUX_SOCKET" new-session -d -s "$SESSION" "$worker"
    exit 0
fi

if [ "$action" = "stop" ]; then
    # 从 START 行取出本次采集器的 PID，只停这一个实例
    pid=$(sed -n "s/^START $TOKEN pid=//p" "$log" 2>/dev/null | head -n 1)
    if [ -n "$pid" ]; then
        kill -TERM "$pid" 2>/dev/null || true
        n=0
        while [ "$n" -lt 100 ]; do
            state=$(ps -o stat= -p "$pid" 2>/dev/null | tr -d ' ' || true)
            [ -z "$state" ] && break
            case "$state" in
                Z*) break ;;
            esac
            sleep 0.05
            n=$((n + 1))
        done
    fi
    # 采集器退出后会话通常已自行结束，这里兜底结束指定会话（不影响其他会话）
    tmux -L "$TMUX_SOCKET" kill-session -t "$SESSION" 2>/dev/null || true
    exit 0
fi
