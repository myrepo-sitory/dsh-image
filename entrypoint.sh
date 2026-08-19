#!/bin/sh
set -e

# DSH_HOME 未设置时用镜像内默认（~/.dsh）
DSH_HOME_DIR="${DSH_HOME:-$HOME/.dsh}"
PORT="${PORT:-3080}"

# DSH 默认只监听 127.0.0.1，端口映射连不上；启动前写好 webserver 补丁。
# 该文件由 DSH 启动器在首次启动时自动初始化 profile 目录，已存在的文件不会被覆盖（已核对 DSH 源码）。
mkdir -p "$DSH_HOME_DIR/profiles/web"
if [ ! -f "$DSH_HOME_DIR/profiles/web/cordis.patch.yml" ]; then
  printf '%s\n' '- id: webserver' '  config:' '    host: 0.0.0.0' '    port: !!js ctx.webStartup.port ?? 3080' > "$DSH_HOME_DIR/profiles/web/cordis.patch.yml"
fi

# 日志里打印版本，方便确认跑的是哪个版本
echo "[dsh-entrypoint] starting DSH $(dsh --version 2>/dev/null || echo 'unknown') on port ${PORT}"

exec dsh web --port "$PORT"
