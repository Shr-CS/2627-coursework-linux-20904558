#!/bin/bash
# Q6：将本地 Debian 包安装到 output/sysroot，运行安装后的工具。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

root="$output/sysroot"

# 1) 准备 sysroot 内的 dpkg 数据库骨架：普通用户写不了系统 /var/lib/dpkg，
#    数据库必须落在 sysroot 里（status 只创建，不截断，重复运行安全）
mkdir -p "$root/var/lib/dpkg/info" "$root/var/lib/dpkg/updates" "$root/var/lib/dpkg/triggers"
: >> "$root/var/lib/dpkg/status"

# 2) 非 root 安装：
#    --root         安装根目录，文件落到 sysroot，admindir 跟着变成 sysroot/var/lib/dpkg
#    --force-not-root 允许普通用户安装（文件属主保持当前用户）
#    --log=/dev/null  否则 dpkg 会去写系统 /var/log/dpkg.log 而失败
dpkg --root="$root" --force-not-root --log=/dev/null \
    -i "$input/aim-sentry-tools.deb"

# 3) 运行安装进 sysroot 的工具，保存它唯一的一行输出
"$root/usr/bin/aim-sentry-info" > "$output/tool-output.txt"
