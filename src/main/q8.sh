#!/bin/bash
# Q8：repair 时识别并停止采集器、修复 HTTP 服务；cleanup 时停止修复后的服务。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

action=${3:-repair}

# 教师为本次场景生成的进程与服务参数
source "$input/process.env"

# 进程状态：空表示进程已不存在，Z 开头表示僵尸（两者都算已结束）
proc_state() {
    ps -o stat= -p "$1" 2>/dev/null | tr -d ' ' || true
}

# 等待进程真正结束：收到 TERM 后它还要写完 STOP 记录、关闭监听端口
wait_stopped() {
    pid=$1
    n=0
    while [ "$n" -lt 100 ]; do
        state=$(proc_state "$pid")
        [ -z "$state" ] && return 0
        case "$state" in
            Z*) return 0 ;;
        esac
        sleep 0.05
        n=$((n + 1))
    done
}

if [ "$action" = "repair" ]; then
    # A1 进程识别：pid / user / state / command，每行一个 key=value
    {
        printf 'pid=%s\n' "$TARGET_PID"
        printf 'user=%s\n' "$(stat -c %U "/proc/$TARGET_PID")"
        printf 'state=%s\n' "$(proc_state "$TARGET_PID")"
        printf 'command=%s\n' "$(tr '\0' ' ' < "/proc/$TARGET_PID/cmdline")"
    } > "$output/process.txt"

    # A2 采集日志：完整保存目标采集器已经写出的日志（含 START 行）
    cp "$WORKER_LOG" "$output/collector-sample.log"

    # A3 只按 PID 停目标采集器：SIGTERM 让它自己写完 STOP 再退出，
    #    不能用 killall / pkill，否则会误杀同名的另一个采集器
    kill -TERM "$TARGET_PID"
    wait_stopped "$TARGET_PID"

    # B1 先停掉错误配置的原 HTTP 服务，释放它占用的端口
    kill -TERM "$SERVICE_PID"
    wait_stopped "$SERVICE_PID"

    # B2 写出修正后的配置：绑定地址和路由固定，端口用本次场景的值
    printf 'bind=127.0.0.1\nport=%s\nroute=/status\n' "$TARGET_PORT" > "$output/server.conf"

    # B3 用教师提供的启动器拉起新服务（它只负责启动，等待和验证由我们做）
    bash "$START_TOOL" "$output/server.conf" "$output/service"

    # B4 有界重试地实际请求一次，保存状态码和响应体
    #    --noproxy：本机请求不该走任何代理；--max-time：单次请求超时，避免无界等待
    status=
    n=0
    while [ "$n" -lt 100 ]; do
        if status=$(curl -s --noproxy '*' --max-time 2 \
            -o "$output/http-body.txt" -w '%{http_code}' \
            "http://127.0.0.1:$TARGET_PORT/status"); then
            break
        fi
        status=
        sleep 0.05
        n=$((n + 1))
    done
    printf '%s\n' "$status" > "$output/http-status.txt"
    exit 0
fi

if [ "$action" = "cleanup" ]; then
    # 只停 repair 启动的那个服务，PID 由启动器写在 service/pid
    if [ -f "$output/service/pid" ]; then
        pid=$(cat "$output/service/pid")
        kill -TERM "$pid" 2>/dev/null || true
        wait_stopped "$pid"
        case "$(proc_state "$pid")" in
            ""|Z*) ;;
            *)
                kill -KILL "$pid" 2>/dev/null || true
                wait_stopped "$pid"
                ;;
        esac
    fi
    exit 0
fi
