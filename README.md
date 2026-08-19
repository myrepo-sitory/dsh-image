# 把 DSH 打包成镜像并发布到 GitHub（ghcr.io），NAS 上一条 compose 拉取即用

这个仓库里的文件组成一个**完全可审计**的 DSH 镜像：
- `Dockerfile` —— 基于官方 `node:22-bookworm-slim` + 官方 npm 包 `@deepseek-ai/dsh`（版本已锁定 `0.1.0-rc.7`），没有任何第三方魔法
- `entrypoint.sh` —— 启动时自动写好 DSH 必需的端口补丁，然后启动 Web 服务
- `.github/workflows/publish.yml` —— 自动构建并发布到 ghcr.io（GitHub 容器仓库）
- `docker-compose.yml` —— NAS 上直接用的编排文件
- `.dockerignore` —— 构建时排除无关文件，加快构建
- `MIRRORS.md` —— **拉取失败排查手册**（换加速源/导出导入/常见报错）
- `pull.sh` —— **自动尝试多个镜像源的拉取脚本**（成功即导出 tar 供 NAS 导入）

**已做的优化**：npm 缓存走构建缓存挂载（不进镜像、改版本后重建秒级命中）；一次构建同时打 `:latest` 和 `:0.1.0-rc.7` 两个 tag（可锁版本回滚）；GitHub Actions 开启构建缓存 + 供应链证明（provenance/SBOM）；镜像带 OCI 元数据（来源仓库、提交号）；compose 加了 `init`（进程回收）和日志滚动（防占满 NAS 磁盘）；启动日志打印 DSH 版本号便于核对。

> 与论坛那个 `myflv/dsh-gateway` 相比：这个镜像的每一行你都能看到、能审计，版本锁定可复现，API Key 只存在于你自己的 NAS 配置里，不进镜像、不进仓库。

> 📁 **两种部署方案并存**：本目录（根目录）是 **Caddy 版**（自签 HTTPS，`https://NAS-IP:3443`）；`tailscale/` 子目录是 **Tailscale 版**（真证书、零警告、可远程访问，`https://dsh.<tailnet>.ts.net`）。两者共用同一镜像，切换只需换 compose 项目，详见 `tailscale/README.md`。

---

## 第一部分：发布镜像到 GitHub（一次性，约 10 分钟，全程网页点选）

### 第 1 步：注册/登录 GitHub
打开 https://github.com 注册（免费，需要邮箱验证）。已有账号直接登录。

### 第 2 步：创建仓库（注意两件事：公开 + 小写）
1. 右上角 `+` → **New repository**
2. Repository name 填：`dsh-image`（**必须小写**，ghcr.io 不认大写）
3. 可见性选 **Public**（公开；构建动作免费且 NAS 拉取不需要登录）
4. 其他默认，点 **Create repository**

### 第 3 步：上传文件
在新仓库页面点 **Add file → Upload files**，把本目录下的文件拖进去（**前 4 个是构建必需的**，后 3 个建议也传，方便以后查）：
- `Dockerfile` ✅必需
- `entrypoint.sh` ✅必需
- `.dockerignore` ✅必需
- `.github/workflows/publish.yml` ✅必需（注意这个嵌套路径，网页上传时会自动建文件夹）
- `docker-compose.yml`、`MIRRORS.md`、`pull.sh`（建议一并上传）

点 **Commit changes** 提交。

### 第 4 步：给 Actions 开"写"权限（默认是只读，不开会构建失败）
1. 仓库页面点 **Settings**（齿轮）→ 左侧 **Actions → General**
2. 找到 **Workflow permissions**，选 **Read and write permissions**
3. **Save**

### 第 5 步：触发构建
- 刚才的提交会自动触发（页面上方会出现黄色/绿色的 Actions 徽标）；
- 也可以在 **Actions** 标签页 → 左侧 `build-publish` → 右侧 **Run workflow** 手动跑一次。
- 等待约 3~5 分钟，构建步骤全部打勾变绿即成功。

### 第 6 步：把镜像包设为公开（默认是私有，NAS 拉不到）
1. 点头像 → **Your profile** → 上方 **Packages** 标签
2. 点开 `dsh-image` 这个包 → 右侧 **Package settings**
3. **Change visibility** → 选 **Public** → 确认

现在镜像地址就是：`ghcr.io/你的用户名/dsh-image:latest`（把"你的用户名"换成实际名字）。

---

## 第二部分：NAS 上拉取部署（Docker 图形界面）

1. 打开 UGOS Docker 应用 →「**项目**」→ 新建 → 选 Compose 方式；
2. 粘贴本目录 `docker-compose.yml` 的内容，改两处：
   - `image:` 改成 `ghcr.io/你的用户名/dsh-image:latest`
   - `DEEPSEEK_API_KEY` 改成你的 `sk-...`
3. 创建并启动；
4. 看容器日志，出现 `dsh web: http://127.0.0.1:3080` 即成功；
5. 浏览器打开 `http://<NAS的IP>:3080`，发一条消息验证。

> 如果你的 Docker 应用没有「项目/Compose」入口：也可以拉镜像 `ghcr.io/你的用户名/dsh-image:latest` 后按单容器创建（端口 3080→3080，环境变量 `DSH_HOME=/data`、`DEEPSEEK_API_KEY`、`TZ=Asia/Shanghai`，卷 `data→/data`、`workspace→/workspace`，命令框留空即可——镜像自带入口脚本）。

---

## 官方更新了 DSH，我的镜像会自动更新吗？

**默认不会**。原因：镜像在"构建那一刻"把指定版本的 npm 包装进去，构建后就是静态的；构建只在"你的仓库有提交 / 你手动点 Run / 每周定时"时触发。DeepSeek 官方发新版不会自动触发你的构建。

**两种模式（改 `Dockerfile` 里的 `ARG DSH_VERSION` 即可切换）：**

| ARG 的值 | 行为 | 适合 |
|---|---|---|
| `0.1.0-rc.7`（锁定，默认） | 稳定不变；官方更新后**手动**改版本号 → 提交 → 自动重建 | 求稳，不想被新版本影响 |
| `latest` | **自动跟随**：配合每周定时重建，官方发版后最多一周内自动构建出最新版 | 想省心，随时用最新 |

**切换后记得**：
1. NAS 上更新容器才能用上新镜像：`docker compose pull && docker compose up -d`（或图形界面"更新/重新拉取"）；
2. 想随时手动触发一次重建（不等每周定时）：仓库 Actions 页 → `build-publish` → **Run workflow**；
3. compose 里 `image:` 若锁了版本号 tag，跟随最新时记得改回 `:latest`。

## 拉取失败怎么办（重要）

国内网络拉 ghcr.io 经常失败，**解决方案已打包在本仓库里**：
- **先看 `MIRRORS.md`**：按里面的"现象对照表"判断是网络问题还是镜像不存在，然后照第 1 节把 `image:` 前缀换成加速站（如 `ghcr.nju.edu.cn`）逐个试；
- **加速站全失效**：在任意装了 Docker 的电脑上跑 `bash pull.sh 你的GitHub用户名 latest`，它会自动尝试多个镜像源，成功后导出 `dsh.tar`，再到 NAS 的 Docker →「镜像」→「导入」即可（详见 MIRRORS.md 第 2 节）；
- 常见坑速查：报 `not found/manifest unknown` = 包还没设 Public 或用户名拼错；报 `timeout/403` = 网络问题走加速。

## 不用 GitHub 的备选（在电脑上本地构建）

如果你不想用 GitHub Actions，也可以在自己电脑上构建再导入 NAS：
1. 电脑装 Docker Desktop，进入本目录执行：
   ```
   docker build -t dsh-local .
   docker save -o dsh.tar dsh-local
   ```
2. 把 `dsh.tar` 传到 NAS → Docker「镜像」→「导入」→ 选 `dsh-local` → 按上面的单容器方式创建。

---

## 安全说明（重要）

- 本镜像**没有内置登录认证**（DSH 官方 v1 如此），`/api` 具备执行命令能力。默认 `3080:3080` 只适合**可信家庭内网**；NAS 若对公网开放端口，务必先在前面加认证（Caddy basic auth / Tailscale），或把端口映射改为 `127.0.0.1:3080:3080`。
- 仓库是 Public 的，等于任何人都能看你的 Dockerfile——没关系，里面没有任何秘密；`DEEPSEEK_API_KEY` 只写在 NAS 本地的 compose 里，不要提交到仓库。
