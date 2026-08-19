# 镜像拉取失败排查手册（MIRRORS.md）

> 适用：NAS 上 `docker pull` / Docker 图形界面拉取 `ghcr.io/你的用户名/dsh-image` 失败时。
> 自动尝试多源的脚本见同目录 `pull.sh`。

## 0. 先判断是哪一种失败

| 现象 | 结论 |
|---|---|
| 报 `connection refused` / `timeout` / `i/o timeout` / `403` / `429` / `TLS handshake timeout` | **网络问题**（最常见）：ghcr.io 在国内被限速/阻断 → 用第 1 节 |
| 报 `manifest unknown` / `not found` / `no such manifest` | **镜像不存在**：用户名拼错、包还没设为 Public、或者 tag 不对 → 检查第 3 节 |
| 报 `no space left on device` | NAS 磁盘满，清理空间 |

## 1. 网络问题：换加速前缀（90% 的情况靠这个解决）

完整镜像地址 = `仓库前缀` + `/` + `用户名/dsh-image:版本`。把前缀从 `ghcr.io` 换成下面任一加速站即可，**后面的部分不变**：

```
ghcr.nju.edu.cn/你的用户名/dsh-image:latest
ghcr.dockerproxy.com/你的用户名/dsh-image:latest
ghcr.m.daocloud.io/你的用户名/dsh-image:latest
```

**怎么换（图形界面）**：Docker 应用 →「项目」→ 打开 dsh 项目 → 编辑 → 把 `image:` 那一行的 `ghcr.io/...` 改成 `ghcr.nju.edu.cn/...` → 保存并重新拉取。

**逐个试**：加速站有地域差异，A 家不行就试 B 家、C 家，换一个地址点一次"拉取"，通常第三个以内就能成。

> ⚠️ 公共加速站是"活"的，随时可能失效或新增，**以实时列表为准**：
> - 绿联官方社区「境内 Docker 镜像状态监控 & 镜像加速」：https://club.ugnas.com/thread-814-1-18.html
> - GitHub 汇总（持续更新）：https://github.com/SeanChang/xuanyuan_docker_proxy 、 https://github.com/zlibrarya/DockerHub

## 2. 加速站全失效：电脑导出 → NAS 导入（100% 成功）

任何加速都拉不动时，用一台能上网的电脑（Windows 装 Docker Desktop 即可）执行：

```bash
# 方法一：自动尝试多个镜像源，成功即导出（推荐）
bash pull.sh 你的GitHub用户名 latest

# 方法二：手动指定一个源
docker pull ghcr.nju.edu.cn/你的用户名/dsh-image:latest
docker tag ghcr.nju.edu.cn/你的用户名/dsh-image:latest dsh-local:latest
docker save -o dsh.tar dsh-local:latest
```

然后把生成的 `dsh.tar` 传到 NAS（UGOS 文件管理 → 上传到任意目录）→ Docker 应用 →「镜像」→「**导入 / 加载镜像**」→ 选择 `dsh.tar` → 镜像列表出现 `dsh-local` → 创建容器时选它（端口/环境变量/卷配置不变，命令框留空）。

## 3. 镜像"不存在"类错误的排查

1. **包是否已设为 Public**：GitHub → 你的头像 → Packages → 打开 `dsh-image` → Package settings → Change visibility → **Public**（默认私有，NAS 无凭证拉不到，报 not found）；
2. **用户名是否拼对**：必须是 GitHub 用户名（小写），不是仓库名；镜像地址是 `ghcr.io/<用户名>/dsh-image`，仓库名 `dsh-image` 是镜像名；
3. **tag 是否存在**：`latest` 和 `0.1.0-rc.7` 两个都有（每次构建都发布）；旧 tag 不会自动消失，想删去 GitHub Packages 页面管理；
4. **Actions 是否真的成功**：仓库 Actions 页看 `build-publish` 是否全绿；红了就点进失败的步骤看日志，常见原因是忘了开「Workflow permissions → Read and write」。

## 4. 在 NAS 上验证拉取是否通了

（会 SSH 的话）登录 NAS 执行：
```bash
docker pull ghcr.nju.edu.cn/你的用户名/dsh-image:latest && echo 拉取成功
```
能出现镜像 id 就说明这条路通了，接下来放心用 compose 创建容器。

## 5. 治本：给 Docker 配置镜像加速（可选）

如果 NAS 的 Docker 应用「设置」里有「镜像加速 / Registry Mirror」选项，把加速站地址加进去，之后部分场景会自动走加速。注意：**daemon 级 registry-mirrors 只对 Docker Hub 生效，ghcr.io 的镜像不适用**——ghcr 只能靠第 1 节的"换前缀"方式，这一点别搞混。
