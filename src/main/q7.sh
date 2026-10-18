#!/bin/bash
# Q7：读取 input/remote.env，生成 ssh_config，用 SSH 和 SCP 获取远程数据。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

# 教师为本次场景生成的连接参数
source "$input/remote.env"

config="$output/ssh_config"

# 1) 客户端配置：所有连接信息都来自参数，不要写死主机、端口或密钥路径。
#    密钥和 known_hosts 的路径可能含空格，ssh_config 里必须加双引号。
{
    printf 'Host aim-sentry\n'
    printf '    HostName %s\n' "$HOST"
    printf '    Port %s\n' "$PORT"
    printf '    User %s\n' "$REMOTE_USER"
    printf '    IdentityFile "%s"\n' "$KEY_PATH"
    printf '    IdentitiesOnly yes\n'
    printf '    StrictHostKeyChecking yes\n'
    printf '    UserKnownHostsFile "%s"\n' "$KNOWN_HOSTS"
    printf '    BatchMode yes\n'
} > "$config"

# 2) 配置文件里可能有私钥路径，权限收紧到 600
chmod 600 "$config"

# 3) 用别名执行远程命令，返回值就是远程 whoami 的结果
remote_user=$(ssh -F "$config" aim-sentry whoami)
printf '%s\n' "$remote_user" > "$output/remote-user.txt"

# 4) 用 SCP 把远程日志取回本地（远程路径可能含空格，整体作为一个参数传）
mkdir -p "$output/received"
scp -F "$config" "aim-sentry:$REMOTE_LOG" "$output/received/errors.log"
