# 题解与自测记录（AIM 2627 Linux Coursework）

## 0. 为什么这份说明不在根目录 README.md

`README.md`、`Problem.pdf`、`tests/`、`tools/` 都是教师模板文件。CI 的第一步会运行
`tools/check_integrity.py`，它只允许 `src/main/q1.sh`–`q8.sh`、`src/main/bonus.sh`
以及 `.agent-sessions/` 下的文件出现在 `git diff` 里：

```text
只允许修改 src/main/q1.sh–q8.sh、bonus.sh 和 AI 会话归档
```

也就是说，改根 README 会让基础设施检查直接失败，跑不到评分步骤，等于没有成绩。
所以题解、自测记录统一放在 `.agent-sessions/SOLUTIONS.md`，这是课程明确允许提交的位置。

## 1. 总览

| 题 | 脚本 | 主要产物 | 考察点 |
|---|---|---|---|
| Q1 | `q1.sh` | `location.txt`、`robot-id.txt`、`welcome.txt` | `cd` / `pwd` / `cat`，路径规范化 |
| Q2 | `q2.sh` | `sentry_ws/{scripts,config,logs,tmp}` | `mkdir -p`、重定向创建文件、幂等 |
| Q3 | `q3.sh` | 复制、备份、归档、权限、`hello-output.txt` | `cp` / `rm -rf` / `chmod` 精确权限 |
| Q4 | `q4.sh` | `all/errors/attention/recent/first-errors.log`、`error-count.txt` | `cat` / `grep` / `head` / `tail` / `wc` |
| Q5 | `q5.sh` | `stdout.log`、`stderr.log`、`exit-code.txt`、`report.txt` | 重定向、真实 `$?`、条件判断 |
| Q6 | `q6.sh` | `sysroot/`、`tool-output.txt` | `dpkg --root` 非 root 安装 |
| Q7 | `q7.sh` | `ssh_config`、`remote-user.txt`、`received/errors.log` | `ssh -F` / `scp -F`、公钥认证 |
| Q8 | `q8.sh` | `process.txt`、`collector-sample.log`、`server.conf`、`http-*.txt` | `ps` / `kill` / `curl` 排障 |
| Bonus | `bonus.sh` | `bonus.log`、分离的 tmux 会话 | `tmux -L … -d`、会话与进程清理 |

每题都满足题面要求的两条硬约束：**连续运行两次结果不变**，**输入素材不被修改**。

## 2. 逐题说明

### Q1 找到开发目录

```bash
input=$(cd "$input" && pwd)   # 先规范成绝对路径，避免 cd 之后相对路径失效
cd "$input/handover"
pwd > "$output/location.txt"  # pwd 给出真实绝对路径，不是示例路径
```

`.robot-id` 用 `cat` 整体读取，不能用 `ls` 或 `echo *`——隐藏文件不会被通配符匹配。
`location.txt` 必须等于 `INPUT/handover` 的绝对路径，所以先 `cd` 再 `pwd` 最稳。

### Q2 建立工作区

目录用 `mkdir -p`（重复运行不报错），文件用重定向覆盖写（`>` 而不是 `>>`，第二次运行
不会把内容翻倍）。两个空文件用 `: > file`，`touch` 也行，但重定向能保证内容确实是空的。

### Q3 整理与权限

顺序很重要：先建目录 → 复制 → 归档 → 删 `tmp/` → 设权限 → 最后才执行脚本。

- 草稿只进 `archive/draft.conf.old`，**不能**留在 `config/`；
- `tmp/` 指的是**输出**工作区里的 `sentry_ws/tmp`（测试器会预置 `cache.txt`，只 `rm` 文件不删目录会被发现）；
- 输入素材一律只读，草稿是复制而不是从输入里 `mv` 走；
- `chmod 750` / `640` 要在执行脚本之前，`750` 顺带给了执行位，脚本才能直接跑。

### Q4 从日志中找到真相

```bash
cat "$input/boot.log" "$input/run.log" > "$output/all.log"
grep "^ERROR " "$all" > "$output/errors.log" || true
```

三个要点：

1. 只认**行首**的 `ERROR `，`INFO … previous ERROR has been handled` 不算错误；
2. 无匹配时 `grep` 返回 1，`set -e` 会直接终止脚本，所以提取类命令要 `|| true`；
3. `grep -c` 无匹配时输出 `0` 但同样返回 1，`error_count=$(grep -c … || true)` 才能拿到那个 `0`。

`|| true` 只加在"没有匹配是正常输入"的地方，不加在 `cat`、`tail` 这类真错误必须暴露的命令上。

### Q5 启动故障诊断

```bash
if bash "$LAUNCH_TOOL" "$MODEL_PATH" "$CAMERA_PATH" \
    > "$output/stdout.log" 2> "$output/stderr.log"; then
    exit_code=0
else
    exit_code=$?
fi
```

这是本题的核心陷阱：**不能用 `cmd || true` 再取 `$?`**，那样拿到的是 `true` 的 0。
`if` 的 `else` 分支里 `$?` 才是被检查程序的真实退出码。判定也只看退出码：

| 退出码 | result | reason |
|---|---|---|
| 0 | SUCCESS | NONE |
| 10 | FAILED | MODEL_MISSING |
| 20 | FAILED | CAMERA_DENIED |

`stderr` 非空不等于失败（`ready` 场景也会打印 `NOTICE`），所以不能用它判断。

### Q6 安装开发工具

```bash
mkdir -p "$root/var/lib/dpkg/info" "$root/var/lib/dpkg/updates" "$root/var/lib/dpkg/triggers"
: >> "$root/var/lib/dpkg/status"
dpkg --root="$root" --force-not-root --log=/dev/null -i "$input/aim-sentry-tools.deb"
```

- `--root` 同时把安装目录和 dpkg 数据库指到 `sysroot`，不碰真实系统；
- 普通用户写不了 `/var/log/dpkg.log`，必须 `--log=/dev/null`；
- `--force-not-root` 允许非 root 安装（文件属主是当前用户，权限仍按包内记录）；
- 先建好 `var/lib/dpkg` 骨架（含空 `status`），等价于 debootstrap 的做法，避免 dpkg 找不到数据库。

安装后直接执行 `sysroot/usr/bin/aim-sentry-info`，把输出存成 `tool-output.txt`。

### Q7 远程连接与日志回收

```bash
printf '    IdentityFile "%s"\n' "$KEY_PATH"
printf '    UserKnownHostsFile "%s"\n' "$KNOWN_HOSTS"
```

两个坑都是路径里的空格：

1. `ssh_config` 里带空格的路径**必须加双引号**，否则报
   `keyword identityfile extra arguments at end of line`；
2. 选项名是 `UserKnownHostsFile`（`UserKnownHosts` 不是通用写法，会报
   `Bad configuration option`）。

配置里 `IdentitiesOnly yes` + `StrictHostKeyChecking yes` + `BatchMode yes` 一起用，
既不探测 `~/.ssh` 下的其他密钥，也不会卡在交互提问上；`ssh_config` 本身 `chmod 600`。
`scp` 的远程路径整体作为一个参数传入（`"aim-sentry:$REMOTE_LOG"`），空格才不会把路径拆开。

### Q8 进程与服务排障

**repair**

| 步骤 | 命令 | 说明 |
|---|---|---|
| 识别进程 | `stat -c %U /proc/PID`、`ps -o stat= -p PID`、`tr '\0' ' ' < /proc/PID/cmdline` | 不用 `ps -o user=`：procps 会把用户名截到 8 字符 |
| 采集日志 | `cp "$WORKER_LOG" …` | 保留 `START` 和全部 `TICK` |
| 停采集器 | `kill -TERM "$TARGET_PID"` | 按 PID 停，`killall`/`pkill` 会误杀同名实例 |
| 停旧服务 | `kill -TERM "$SERVICE_PID"` | 必须在启动新服务之前，否则端口被占 |
| 修配置 | `bind=127.0.0.1` / `port=$TARGET_PORT` / `route=/status` | 三行，顺序固定 |
| 起服务 | `bash "$START_TOOL" "$output/server.conf" "$output/service"` | 启动器只负责拉起 |
| 验证 | `curl --noproxy '*' …/status` | 有界重试，落 `http-status.txt` / `http-body.txt` |

`wait_stopped` 会一直等到进程消失或变成僵尸：`SIGTERM` 之后采集器还要写 `STOP` 记录、
服务还要关闭监听端口，立刻往下走会读到半成品。

**cleanup** 只读 `service/pid` 停掉 repair 启动的那个服务，先 `TERM` 再 `KILL` 兜底，
不动其他进程，也不改已经生成的报告。

### Bonus 保持会话

```bash
worker="exec python3 $(printf '%q' "$WORKER_TOOL") --token $(printf '%q' "$TOKEN") --log $(printf '%q' "$log")"
tmux -L "$TMUX_SOCKET" new-session -d -s "$SESSION" "$worker"
```

`-d` 让会话分离，脚本退出后采集器继续写日志；`printf %q` 负责把含空格的路径转义好再交给
tmux 的 `sh -c`。`exec` 让 python 直接成为 pane 进程，停掉它就等于结束会话。
`stop` 从日志的 `START … pid=` 行取 PID，只停这一个实例，再 `kill-session` 兜底结束指定会话。

## 3. 踩坑清单

| 现象 | 原因 | 处理 |
|---|---|---|
| 脚本莫名中途退出 | `set -e` + 命令返回非 0 | 提取类命令 `\|\| true`，其余让错误暴露 |
| 无错误日志时整题 0 分 | `grep` 无匹配返回 1 | `grep … \|\| true` |
| 退出码总是 0 | `cmd \|\| true` 后取 `$?` | 用 `if cmd; then … else code=$?; fi` |
| `ssh: Bad configuration option` | 选项名写错 | 用 `UserKnownHostsFile` |
| `keyword identityfile extra arguments` | 路径含空格未加引号 | 配置里加双引号 |
| `user=` 只剩 8 个字符 | `ps -o user=` 截断 | `stat -c %U /proc/PID` |
| `http-status.txt` 是 502 | `curl` 走了环境代理 | `--noproxy '*'` |
| 第二次运行产物翻倍 | 用了 `>>` | 一律 `>` 覆盖写 |
| 输入素材被改动 | 直接对输入 `mv`/`rm` | 只在输出目录里操作 |

## 4. 自测方式

正式自测（唯一有效的判分方式）在 Ubuntu 24.04 上：

```bash
bash tools/test.sh                          # 全部题目
bash tools/test.sh --question Q4 --verbose   # 单题并查看成功执行的输出
```

本机是 macOS，无法跑官方测试器（需要 root、`useradd`、`sshd`、`dpkg`、`tmux`），
已做的等价验证：

| 题 | 本地验证 |
|---|---|
| Q1–Q5 | 用 `tests/coursework.py` 的同一批输入和断言复刻了全部公开场景（含两次运行、输入不变、权限、内容逐字节比较），全部通过 |
| Q6 | 无法验证（macOS 无 dpkg），按 `--root/--force-not-root/--log` 的官方语义编写 |
| Q7 | 起真实 sshd 后用 `ssh -G -F` 校验别名、密钥、`known_hosts`、`StrictHostKeyChecking`、`IdentitiesOnly` 全部解析正确；本机 sshd 因系统沙箱无法完成握手，`scp` 留待 CI |
| Q8 | 用真实 worker/service 进程跑通 `wrong-port`、`wrong-route` 两个场景：进程识别、`STOP` 记录、不误杀、配置修复、HTTP 200、`cleanup` 释放端口 |
| Bonus | 无法验证（本机无 tmux） |

## 5. 提交

每个题目一个 commit，最终状态一次性推送；正式成绩以与最新 commit 对应的
Actions run 为准（必做 ≥ 60 分且 Q7、Q8 全部检查通过）。
