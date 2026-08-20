#!/bin/sh
set -e

# DSH_HOME 未设置时用镜像内默认（~/.dsh）
DSH_HOME_DIR="${DSH_HOME:-$HOME/.dsh}"
PORT="${PORT:-3080}"
PATCH_FILE="$DSH_HOME_DIR/profiles/web/cordis.patch.yml"

# ── 可选：局域网 HTTP 访问修复插件 ──────────────────────────────
# 背景：浏览器只在 HTTPS/localhost 下提供 crypto.randomUUID，DSH 前端依赖它，
#       所以 http://<局域网IP>:3080 明文访问时聊天/选模型/选目录会报
#       "crypto.randomUUID is not a function"（官方已知：deepseek-ai/deepseek-harness#2396）。
# 方案 C：装社区插件 dsh-web-lan-access（第三方代码，风险自担）来修复。
# 重要：该插件是 bundle 型插件（package.json 声明 dsh.bundle.patch），
#       `dsh plugin add` 成功后会自动把它注册进 profile 的 bundles 层并生效，
#       不需要也不应该再往 cordis.patch.yml 里手写启用行（否则会重复挂载同一插件）。
# 想跳过：把下面这行改成 LAN_PLUGIN="" 即可。
LAN_PLUGIN="dsh-web-lan-access"

mkdir -p "$DSH_HOME_DIR/profiles/web"

# 1) webserver 补丁：DSH 默认只监听 127.0.0.1，端口映射连不上。
#    该文件由 DSH 启动器首次启动时自动初始化 profile 目录，已存在的文件不会被覆盖（已核对 DSH 源码）。
if [ ! -f "$PATCH_FILE" ]; then
  printf '%s\n' '- id: webserver' '  config:' '    host: 0.0.0.0' '    port: !!js ctx.webStartup.port ?? 3080' > "$PATCH_FILE"
fi

# 2) 局域网访问修复插件：没装就装（幂等；安装失败不阻塞启动，下次重启重试）
if [ -n "$LAN_PLUGIN" ] && [ ! -d "$DSH_HOME_DIR/profiles/web/node_modules/$LAN_PLUGIN" ]; then
  echo "[dsh-entrypoint] 安装局域网访问插件 $LAN_PLUGIN ..."
  if (cd "$DSH_HOME_DIR/profiles/web" && dsh plugin --profile web add "$LAN_PLUGIN" --registry=https://registry.npmmirror.com); then
    echo "[dsh-entrypoint] $LAN_PLUGIN 安装并注册成功（bundle 层已生效）"
  else
    echo "[dsh-entrypoint] 插件安装失败（不影响启动，下次重启会重试）"
  fi
fi

# 日志里打印版本，方便确认跑的是哪个版本
echo "[dsh-entrypoint] starting DSH $(dsh --version 2>/dev/null || echo 'unknown') on port ${PORT}"

exec dsh web --port "$PORT"
