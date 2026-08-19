# DSH 打包镜像 —— 基于官方 npm 包 @deepseek-ai/dsh，完全可审计
# 构建与发布由 GitHub Actions 自动完成（见 .github/workflows/publish.yml）
# 拉取失败怎么办见 MIRRORS.md / pull.sh；使用方法见 README.md

# 基础镜像可整体替换（比如锁到精确版本 node:22.20.0-bookworm-slim），默认保持 22 大版本跟随安全更新
ARG NODE_IMAGE=node:22-bookworm-slim
FROM ${NODE_IMAGE}

# 锁定 DSH 版本，保证镜像内容可复现（publish.yml 会读取这个值作为版本 tag）
ARG DSH_VERSION=0.1.0-rc.7

LABEL org.opencontainers.image.title="dsh" \
      org.opencontainers.image.description="DeepSeek Harness Web (official npm package @deepseek-ai/dsh)" \
      org.opencontainers.image.version="${DSH_VERSION}"

# 用 BuildKit 缓存挂载装依赖：npm 缓存留在构建缓存里（不进镜像、不占镜像体积），
# 以后改版本号重构建时秒级命中；需要 BuildKit（GitHub Actions 默认支持，本地 Docker Desktop 也是默认）
RUN --mount=type=cache,target=/root/.npm \
    npm i -g --no-audit --no-fund pnpm @deepseek-ai/dsh@${DSH_VERSION}

WORKDIR /workspace
EXPOSE 3080

COPY entrypoint.sh /usr/local/bin/dsh-entrypoint
RUN chmod +x /usr/local/bin/dsh-entrypoint

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3080/').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

ENTRYPOINT ["/usr/local/bin/dsh-entrypoint"]
