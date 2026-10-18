#!/bin/bash
# Q2：创建 sentry_ws 四个子目录、两个空文件以及指定脚本和配置。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

ws="$output/sentry_ws"

# 1) 目录结构：重复运行不能报错，所以用 mkdir -p
mkdir -p "$ws/scripts" "$ws/config" "$ws/logs" "$ws/tmp"

# 2) 两个空文件：用 : 重定向覆盖，保证第二次运行仍是 0 字节
: > "$ws/logs/.keep"
: > "$ws/tmp/scratch.txt"

# 3) 启动脚本：内容必须与题面逐字一致，且带 shebang
cat > "$ws/scripts/hello.sh" <<'HELLO'
#!/bin/bash
echo "Hello, AIM Linux!"
HELLO

# 4) 配置文件：三行键值，顺序和内容固定
cat > "$ws/config/robot.conf" <<'CONF'
robot=sentry
mode=training
log_level=INFO
CONF
