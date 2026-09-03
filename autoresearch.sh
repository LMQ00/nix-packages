#!/usr/bin/env bash
# AweSun (sunlogin) 可运行性 benchmark
#
# 背景：用户报告向日葵"网络不可用"、不能正常运行，怀疑缺少 systemd 服务。
# 上游 .deb 自带 runawesun.service（systemd 启动 awesun_daemon），Nix 打包未安装它。
# 已知失败机制（derivation 注释 + 实测日志）：
#   daemon 会校验客户端 exe：readlink /proc/<pid>/exe 前缀必须匹配 /usr/local/awesun。
#   若已有一个 store 路径 daemon 在跑（例如误配的 systemd 服务或残留进程），
#   sunlogin-start.sh 的 `pgrep -x awesun_daemon` 会命中 → 跳过正确启动 →
#   GUI 连上错误 daemon 后被 RST（日志 OnRpcClose err=104 / Verify client failed），
#   表现为登录/网络不可用。
#
# Workload（确定性，离线可用；app 的网络请求不进入判定）：
#   A. clean 回归：干净状态 → 用户同款入口启动 → daemon(exe=/usr/local/awesun 前缀)
#      + LISTEN 端口就绪，GUI 稳定连接（无 RST）。
#   B. stale 主场景（复现用户问题）：先启动 store 路径 daemon（模拟误配 systemd /
#      残留进程）→ 再启动 GUI → 度量能否恢复为正确 daemon + 稳定连接。
#
# 指标：
#   primary:  sunlogin_ok           场景 B 最终健康度（1=正确 daemon 存活+GUI 连上+无 RST）
#   secondary: sunlogin_daemon_ready_ms  场景 B 就绪耗时（低=好；超时=哨兵）
#              sunlogin_gui_connected / sunlogin_rpc_rst / sunlogin_daemon_alive
#              sunlogin_clean_ok（场景 A 回归）/ sunlogin_clean_ready_ms
#              sunlogin_systemd_unit（包内是否安装 systemd unit，用户假设）

set -u

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
DISPLAY_NUM=95
export DISPLAY=":$DISPLAY_NUM"
READY_TIMEOUT_S=25
SETTLE_S=5
BASE_TMP="$(mktemp -d /tmp/awesun-harness.XXXXXX)"
WORKDIR="$BASE_TMP/work"
mkdir -p "$WORKDIR"
GUI_LOG="$BASE_TMP/gui.log"
STALE_LOG="$BASE_TMP/stale.log"
XVFB_LOG="$BASE_TMP/xvfb.log"

kill_all_awesun() {
  # bwrap 退出不自动杀子进程（实测 timeout 杀 bwrap 后 daemon/GUI 仍存活），必须显式清理。
  pkill -9 -x awesun_daemon >/dev/null 2>&1 || true
  pkill -9 -x awesun >/dev/null 2>&1 || true
  pkill -9 -f '/usr/local/awesun' >/dev/null 2>&1 || true
  pkill -9 -f 'awesun' >/dev/null 2>&1 || true
  sleep 0.3
}
cleanup() {
  kill_all_awesun
  [ -n "${XVFB_PID:-}" ] && kill "$XVFB_PID" >/dev/null 2>&1 || true
  if [ "${KEEP_TMP:-0}" = 1 ]; then
    echo "KEPT_TMP=$BASE_TMP" >&2
  else
    rm -rf "$BASE_TMP"
  fi
}
trap cleanup EXIT

# ---------- 1. 干净起始状态 ----------
kill_all_awesun
sleep 0.5

# daemon 被 kill -9 后 /tmp/*_16090 /tmp/*_16308 RPC socket 文件残留，
# 会让新 daemon bind EADDRINUSE 启动即退。用户可删的自动清理；
# root 所有的删不掉（/tmp sticky + 非 owner），上报指标供人工处理。
stale_socket_root=0
for f in /tmp/*_16090 /tmp/*_16308; do
  [ -e "$f" ] && rm -f "$f" 2>/dev/null
  [ -e "$f" ] && stale_socket_root=1
done

# ---------- 2. 构建（flake.lock 固定 → store 命中，无网络） ----------
OUT="$(cd "$REPO_ROOT" && NIXPKGS_ALLOW_UNFREE=1 nix build --no-link --print-out-paths .#sunlogin --impure 2>"$BASE_TMP/build.err" | tail -1)"
if [ -z "${OUT:-}" ] || [ ! -x "$OUT/bin/sunlogin" ]; then
  echo "ERROR: sunlogin build failed" >&2
  cat "$BASE_TMP/build.err" >&2 2>/dev/null || true
  exit 1
fi

# 定位 rootfs（含 store 路径符号链接的 opt/awesun/bin/awesun_daemon，用于 stale 场景）
BW="$(readlink -f "$OUT/bin/sunlogin")"
ROOTFS="$(grep -oE '/nix/store/[a-z0-9]+-[^ ]*-fhsenv-rootfs' "$BW" | head -1)"
STALE_DAEMON="$(readlink -f "$ROOTFS/opt/awesun/bin/awesun_daemon" 2>/dev/null)"
[ -n "${STALE_DAEMON:-}" ] && [ -x "$STALE_DAEMON" ] || STALE_DAEMON=""

# ---------- 3. Xvfb ----------
Xvfb ":$DISPLAY_NUM" -screen 0 1280x800x24 -nolisten tcp >"$XVFB_LOG" 2>&1 &
XVFB_PID=$!
for _ in $(seq 1 40); do
  [ -S "/tmp/.X11-unix/X$DISPLAY_NUM" ] && break
  sleep 0.25
done
[ -S "/tmp/.X11-unix/X$DISPLAY_NUM" ] || { echo "ERROR: Xvfb did not start" >&2; exit 1; }

# 正确 daemon 判定：exe 必须是 /usr/local/awesun 前缀（FHS env 内）
correct_daemon_alive() {
  local p
  p="$(pgrep -x awesun_daemon 2>/dev/null | head -1)"
  [ -n "$p" ] || return 1
  readlink "/proc/$p/exe" 2>/dev/null | grep -q '^/usr/local/awesun'
}
listener_up() {
  ss -tlnp 2>/dev/null | grep -q awesun
}
run_launch_and_measure() {
  # $1 = 场景名；$2 = GUI 日志路径；$3 = 稳定窗口秒数（默认 $SETTLE_S）
  # 注意：daemon 会把 sunlogin_rundaemon.log 写进 cwd（bwrap --chdir 继承），
  # 必须在独立 workdir 里启动，避免污染仓库根。
  local name="$1"
  local log="$2"
  local settle="${3:-$SETTLE_S}"
  local ready_file="${4:-}"
  local ready_ms="" t0
  t0="$(date +%s%N)"
  ( cd "$WORKDIR" && exec "$OUT/bin/sunlogin" ) >"$log" 2>&1 &
  APP_PID=$!
  for _ in $(seq 1 $((READY_TIMEOUT_S * 4))); do
    if correct_daemon_alive && listener_up; then
      ready_ms=$(( ($(date +%s%N) - t0) / 1000000 ))
      break
    fi
    sleep 0.25
  done
  [ -n "$ready_ms" ] || ready_ms=$((READY_TIMEOUT_S * 1000))
  sleep "$settle"
  if [ -n "$ready_file" ]; then
    printf '%s' "$ready_ms" >"$ready_file"
  else
    echo "$ready_ms"
  fi
}

# ---------- 场景 A：clean 回归 ----------
export HOME="$BASE_TMP/homeA" XDG_RUNTIME_DIR="$BASE_TMP/xdgA"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
GUI_LOG_A="$BASE_TMP/guiA.log"
cleanA_ready="$(run_launch_and_measure cleanA "$GUI_LOG_A")"
gui_connected_A=0; grep -q 'isConnected: true' "$GUI_LOG_A" 2>/dev/null && gui_connected_A=1
rpc_fail_A="$(grep -c 'OnRpcConnect.*err=-1' "$GUI_LOG_A" 2>/dev/null || true)"
clean_ok=0
[ "$gui_connected_A" = 1 ] && [ "$rpc_fail_A" = 0 ] && clean_ok=1

# 清理场景 A 进程，换全新 HOME
kill_all_awesun
sleep 1

# ---------- 场景 B：stale 前置（用户问题复现） ----------
export HOME="$BASE_TMP/homeB" XDG_RUNTIME_DIR="$BASE_TMP/xdgB"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
if [ -n "$STALE_DAEMON" ]; then
  ( cd "$WORKDIR" && exec setsid "$STALE_DAEMON" -m server -name awesun ) >"$STALE_LOG" 2>&1 < /dev/null &
  for _ in $(seq 1 40); do
    pgrep -x awesun_daemon >/dev/null 2>&1 && break
    sleep 0.25
  done
fi
stale_precondition=0
pgrep -x awesun_daemon >/dev/null 2>&1 && stale_precondition=1
stale_exe_wrong=0
if [ "$stale_precondition" = 1 ]; then
  p="$(pgrep -x awesun_daemon | head -1)"
  readlink "/proc/$p/exe" 2>/dev/null | grep -q '^/usr/local/awesun' || stale_exe_wrong=1
fi

GUI_LOG_B="$BASE_TMP/guiB.log"
# 注意：B 场景 settle 40s 很长，若用命令替换 $(...) 捕获 ready_ms，
# 命令替换子 shell 退出时 bwrap --die-with-parent 会杀 GUI/daemon 树，
# 导致 gui_alive 误判为 0。改为函数内写文件，避免子 shell 包装。
B_READY_FILE="$BASE_TMP/readyB.txt"
# 直接调用（非 $(...) 命令替换）：命令替换子 shell 退出时 bwrap
# --die-with-parent 会杀沙箱进程树（GUI 在树内被误杀，gui_alive 假阴性）
run_launch_and_measure staleB "$GUI_LOG_B" 40 "$B_READY_FILE"
B_ready="$(cat "$B_READY_FILE" 2>/dev/null)"

daemon_alive=0; correct_daemon_alive && daemon_alive=1
gui_alive=0;    pgrep -f '/usr/local/awesun/awesun' >/dev/null 2>&1 && gui_alive=1
gui_crash=0;    grep -qE 'pure virtual|terminate called|SIGSEGV|SIGABRT' "$GUI_LOG_B" 2>/dev/null && gui_crash=1
gui_connected=0; grep -q 'isConnected: true' "$GUI_LOG_B" 2>/dev/null && gui_connected=1
rpc_fail="$(grep -c 'OnRpcConnect.*err=-1' "$GUI_LOG_B" 2>/dev/null || true)"
verify_failed=0;  grep -qi 'Verify client failed' "$GUI_LOG_B" 2>/dev/null && verify_failed=1

ok=0
[ "$daemon_alive" = 1 ] && [ "$gui_alive" = 1 ] && [ "$gui_crash" = 0 ] && [ "$gui_connected" = 1 ] && [ "$rpc_fail" = 0 ] && [ "$verify_failed" = 0 ] && ok=1

# ---------- 场景 C：daemon-mode（systemd ExecStart 语义） ----------
# systemd unit 实际执行的是 SUNLOGIN_DAEMON=1 + $out/bin/sunlogin（bwrap →
# sunlogin-start.sh → 前台 exec awesun_daemon）。GUI 场景已覆盖 start script
# 的 GUI 分支，这里单独验证 daemon 分支：无 GUI，daemon 前台存活 + 监听。
kill_all_awesun
sleep 1
export HOME="$BASE_TMP/homeC" XDG_RUNTIME_DIR="$BASE_TMP/xdgC"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
GUI_LOG_C="$BASE_TMP/guiC.log"
# 同场景 B：避免 $(...) 子 shell 退出触发 bwrap --die-with-parent 杀进程树
C_READY_FILE="$BASE_TMP/readyC.txt"
SUNLOGIN_DAEMON=1 run_launch_and_measure daemonMode "$GUI_LOG_C" "$SETTLE_S" "$C_READY_FILE"
C_ready="$(cat "$C_READY_FILE" 2>/dev/null)"

daemon_alive_C=0; correct_daemon_alive && daemon_alive_C=1
listener_C=0;     listener_up && listener_C=1
daemon_mode_ok=0
[ "$daemon_alive_C" = 1 ] && [ "$listener_C" = 1 ] && daemon_mode_ok=1

# ---------- 场景 D：daemon 复用（生产流程） ----------
# systemd 常驻 daemon 已运行时用户打开 GUI：start script 应识别正确 daemon
# （cmdline 前缀匹配）并复用，不重复启动、不杀掉现有 daemon。
kill_all_awesun
sleep 1
export HOME="$BASE_TMP/homeD" XDG_RUNTIME_DIR="$BASE_TMP/xdgD"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
# 先以 daemon-mode 起一个正确 daemon（等价 systemd 已启动）
# 注意：daemon 会把 sunlogin_rundaemon.log 写进 cwd（bwrap --chdir 继承），
# 必须在独立 workdir 里启动，避免污染仓库根（与 run_launch_and_measure 同约定）
( cd "$WORKDIR" && exec env SUNLOGIN_DAEMON=1 "$OUT/bin/sunlogin" ) >"$BASE_TMP/guiD0.log" 2>&1 &
DAEMON_D_PID=""
for _ in $(seq 1 40); do
  if correct_daemon_alive; then
    DAEMON_D_PID="$(pgrep -x awesun_daemon | head -1)"
    break
  fi
  sleep 0.25
done
[ -n "$DAEMON_D_PID" ] || DAEMON_D_PID="0"
# 再启动 GUI（用户视角）
GUI_LOG_D="$BASE_TMP/guiD.log"
# 同场景 B：避免 $(...) 子 shell 退出触发 bwrap --die-with-parent 杀进程树
D_READY_FILE="$BASE_TMP/readyD.txt"
run_launch_and_measure reuseGUI "$GUI_LOG_D" "$SETTLE_S" "$D_READY_FILE"
D_ready="$(cat "$D_READY_FILE" 2>/dev/null)"

daemon_count_D="$(pgrep -x awesun_daemon | wc -l)"
daemon_alive_D=0; correct_daemon_alive && daemon_alive_D=1
same_pid_D=0
[ "$DAEMON_D_PID" != "0" ] && pgrep -x awesun_daemon | grep -q "$DAEMON_D_PID" && same_pid_D=1
rpc_fail_D="$(grep -c 'OnRpcConnect.*err=-1' "$GUI_LOG_D" 2>/dev/null || true)"
gui_connected_D=0; grep -q 'isConnected: true' "$GUI_LOG_D" 2>/dev/null && gui_connected_D=1
reuse_ok=0
[ "$daemon_alive_D" = 1 ] && [ "$same_pid_D" = 1 ] && [ "$gui_connected_D" = 1 ] && [ "$rpc_fail_D" = 0 ] && reuse_ok=1

# ---------- systemd unit 检查（用户假设） ----------
systemd_unit=0
find "$OUT" -name 'runawesun.service' 2>/dev/null | grep -q . && systemd_unit=1
find "$OUT" -name '*.service' -path '*systemd*' 2>/dev/null | grep -qi awesun && systemd_unit=1

# unit 语法/路径有效性：systemd-analyze verify 对坏 unit 在 stderr 报错
# 但不返回非零（实测 /nonexistent 也是 rc=0），故以输出为空 = 有效
unit_verify=0
verify_out="$(systemd-analyze verify "$OUT/lib/systemd/system/runawesun.service" 2>&1 || true)"
[ -z "$verify_out" ] && unit_verify=1

# ---------- 输出 ----------
echo "METRIC sunlogin_ok=$ok"
echo "METRIC sunlogin_daemon_ready_ms=$B_ready"
echo "METRIC sunlogin_gui_connected=$gui_connected"
echo "METRIC sunlogin_rpc_fail=$rpc_fail"
echo "METRIC sunlogin_daemon_alive=$daemon_alive"
echo "METRIC sunlogin_gui_alive=$gui_alive"
echo "METRIC sunlogin_gui_crash=$gui_crash"
echo "METRIC sunlogin_stale_precondition=$stale_precondition"
echo "METRIC sunlogin_stale_exe_wrong=$stale_exe_wrong"
echo "METRIC sunlogin_clean_ok=$clean_ok"
echo "METRIC sunlogin_clean_ready_ms=$cleanA_ready"
echo "METRIC sunlogin_clean_gui_connected=$gui_connected_A"
echo "METRIC sunlogin_clean_rpc_fail=$rpc_fail_A"
echo "METRIC sunlogin_systemd_unit=$systemd_unit"
echo "METRIC sunlogin_stale_socket_root=$stale_socket_root"
echo "METRIC sunlogin_unit_verify=$unit_verify"
echo "METRIC sunlogin_daemon_mode_ok=$daemon_mode_ok"
echo "METRIC sunlogin_daemon_mode_ready_ms=$C_ready"
echo "METRIC sunlogin_reuse_ok=$reuse_ok"
echo "METRIC sunlogin_reuse_daemon_count=$daemon_count_D"
echo "METRIC sunlogin_reuse_same_pid=$same_pid_D"

[ "$ok" = 1 ] && exit 0 || exit 1
