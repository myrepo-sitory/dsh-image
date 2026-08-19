# Caddy HTTPS 网关镜像：把 Caddyfile 配置打进镜像，NAS 上无需再单独放置配置文件
# 与 dsh 镜像由同一个 workflow 构建发布（见 publish.yml），镜像名：<仓库名>-caddy
# 用法：compose 里 caddy 服务直接用它，不需要 volumes 挂载 Caddyfile
FROM caddy:2-alpine

COPY Caddyfile /etc/caddy/Caddyfile
