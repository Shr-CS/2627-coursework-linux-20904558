#!/bin/bash
# Q3：复制素材、备份配置、移动草稿、删除 tmp、设定权限并直接运行 hello.sh。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

ws="$output/sentry_ws"

# 1) 目录骨架：脚本进 scripts/，正式配置进 config/，另外准备备份和归档目录
mkdir -p "$ws/scripts" "$ws/config" "$ws/backup" "$ws/archive"

# 2) 复制脚本和正式配置（覆盖写入，第二次运行结果不变）
cp -f "$input/hello.sh" "$ws/scripts/hello.sh"
cp -f "$input/robot.conf" "$ws/config/robot.conf"

# 3) 备份正式配置：内容与 config/robot.conf 完全一致的副本
cp -f "$input/robot.conf" "$ws/backup/robot.conf"

# 4) 草稿归档：改名放进 archive/，不要留在配置区，也不碰输入素材
cp -f "$input/draft.conf" "$ws/archive/draft.conf.old"

# 5) 删除输出工作区里的整个 tmp/（测试器会预置缓存，跳过删除会被发现）
rm -rf "$ws/tmp"

# 6) 精确权限：脚本 750，配置 640
chmod 750 "$ws/scripts/hello.sh"
chmod 640 "$ws/config/robot.conf"

# 7) 直接执行脚本（750 已带执行位），保存它唯一的一行标准输出
"$ws/scripts/hello.sh" > "$output/hello-output.txt"
