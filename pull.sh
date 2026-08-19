#!/usr/bin/env bash
# pull.sh —— 自动尝试多个 ghcr 镜像源，拉取 DSH 镜像并导出为 dsh.tar（供 NAS 导入）
#
# 用法（在装了 Docker 的电脑上执行，Windows 用 Git Bash / WSL）：
#   bash pull.sh 你的GitHub用户名 [版本，默认 latest]
#
# 原理：依次尝试 ghcr.io 直连 + 各加速站，第一个成功的就导出。
# 加速站失效/新增时，编辑下面的 SOURCES 数组即可。

set -euo pipefail

USER="${1:?用法: bash pull.sh <GitHub用户名> [版本]}"
VER="${2:-latest}"
NAME="dsh-image"

SOURCES=(
  "ghcr.io/${USER}/${NAME}:${VER}"
  "ghcr.nju.edu.cn/${USER}/${NAME}:${VER}"
  "ghcr.dockerproxy.com/${USER}/${NAME}:${VER}"
  "ghcr.m.daocloud.io/${USER}/${NAME}:${VER}"
)

for src in "${SOURCES[@]}"; do
  echo "==> 尝试: docker pull ${src}"
  if docker pull "${src}"; then
    echo "==> 拉取成功，重命名并导出 dsh.tar ..."
    docker tag "${src}" "dsh-local:${VER}"
    docker save -o dsh.tar "dsh-local:${VER}"
    echo "==> 完成！dsh.tar 已生成。"
    echo "    下一步：把 dsh.tar 上传到 NAS → Docker → 镜像 → 导入 → 选择 dsh-local 创建容器（端口 3080、环境变量、卷配置不变，命令框留空）。"
    exit 0
  fi
  echo "    ${src} 失败，换下一个源 ..."
done

echo "全部镜像源都失败了。"
echo "请检查：1) 网络是否正常；2) 镜像包是否已设为 Public（见 MIRRORS.md 第 3 节）；"
echo "或到 MIRRORS.md 第 1 节找最新可用的加速站，加到上面的 SOURCES 里重试。"
exit 1
