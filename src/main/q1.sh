#!/bin/bash
# Q1：定位 handover，读取隐藏编号和欢迎文本。输出 location.txt、robot-id.txt、welcome.txt。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

# 把传入路径统一规范成绝对路径，避免 cd 之后相对路径失效
input=$(cd "$input" && pwd)
output=$(cd "$output" && pwd)

# 1) 进入 handover/，把当前目录的绝对路径记录下来
cd "$input/handover"
pwd > "$output/location.txt"

# 2) 读取隐藏文件 .robot-id 的完整内容
cat .robot-id > "$output/robot-id.txt"

# 3) 读取欢迎文本的完整内容
cat "$input/notes/welcome.txt" > "$output/welcome.txt"
