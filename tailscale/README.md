# Tailscale 版部署说明

本目录是 **Tailscale 方案**（与仓库根目录的 Caddy 方案并列，互不影响）。
访问方式：`https://dsh.<你的tailnet名>.ts.net` —— **真证书、零警告**，在家、在外面（手机流量）都能打开。

> 为什么选它：你之前的 3443 打不开极可能是 NAS 防火墙拦截入站；Tailscale 是 NAS **主动外连**隧道，天然绕开入站防火墙，同时解决"出门在外访问"和"crypto.randomUUID 安全上下文"两个问题。

---

## 部署步骤（一次性）

### 1. 注册 Tailscale 并开启 HTTPS
1. 打开 https://tailscale.com 注册（免费，支持 GitHub/Google/微软账号登录）；
2. 手机和电脑各装一个 **Tailscale App**，登录**同一个账号**（App 装好后设备会出现在你的 tailnet 里）；
3. 电脑浏览器打开管理台 https://login.tailscale.com/admin → 左侧 **DNS**：
   - 打开 **MagicDNS**；
   - 打开 **HTTPS Certificates**（必须，否则 serve 的证书发不出来）；
4. 记下你的 **tailnet 名**：管理台右上角/设置里能看到，形如 `tail-abc123.ts.net`（或自定义域名）。

### 2. 生成认证密钥（Auth Key）
管理台 → **Settings → Keys → Generate auth key**：
- 有效期选长一点（比如 90 天），勾选"可复用"；
- 生成后复制 `tskey-...` 整串（只显示一次）。

### 3. 改两个文件再部署

**`tailscale/docker-compose.yml`** 里改两处：
- `image:` 的 `你的GitHub用户名` → 你的 GitHub 用户名；
- `TS_AUTHKEY=tskey-你的认证密钥` → 第 2 步复制的密钥。

**`tailscale/serve.json`** 里改一处：
- `"dsh.你的tailnet名.ts.net:443"` → 把 `你的tailnet名` 换成第 1 步记下的名字（形如 `dsh.tail-abc123.ts.net:443`）。

### 4. NAS 上部署（Docker 图形界面）
1. **先停掉旧的 Caddy 项目**（Docker → 项目 → 停止；⚠️ 两个项目共用 `./data`，不能同时运行，否则数据会损坏）；
2. Docker →「项目」→ 新建 → 粘贴改好的 `tailscale/docker-compose.yml` → 创建并启动；
3. 到 `docker/dsh/data/profiles/web/` 下**更新 `cordis.patch.yml`**（文件管理器上传覆盖），内容为下面**完整版**（新增了 connection 信任条目，否则页面能开但发消息会被 403 拒）：

```yaml
- id: webserver
  config:
    host: 0.0.0.0
    port: !!js ctx.webStartup.port ?? 3080

- id: connection
  config:
    trustedHosts: !!js ['dsh.你的tailnet名.ts.net', ...ctx.webRuntime.trustedHosts]
```

> 保存后 DSH 自动热重载，无需重启容器。其中 `dsh.你的tailnet名.ts.net` 要与 serve.json 里的地址一致。

### 5. 验证
1. 看 `dsh-tailscale` 容器日志：出现 `Success.` 或 `Logged out`（正常应显示已登录、serve 配置已应用）；管理台 **Machines** 里能看到 `dsh` 在线；
2. 手机/电脑（登录了同一 Tailscale 账号）浏览器打开：
   ```
   https://dsh.你的tailnet名.ts.net
   ```
   应**直接打开 DSH 界面、无任何警告**，聊天/选模型/选目录全部正常；
3. 在外面（4G/5G）也能打开同一个地址。

---

## 日常与排错

| 现象 | 处理 |
|---|---|
| `dsh-tailscale` 日志报 `auth key ... expired` / 登录失败 | 重新生成 Auth Key，更新 compose 后重建容器 |
| 管理台 Machines 里 `dsh` 显示离线 | 容器没起来或 NAS 断网，看容器日志 |
| 打开地址报"无法连接" | 先确认手机/电脑的 Tailscale App 已登录且在 VPN 开启状态；管理台里 dsh 在线 |
| 页面能开但发消息报 403 | `cordis.patch.yml` 的 connection 条目没生效：检查内容、`dsh.你的tailnet名.ts.net` 是否和实际地址一致、文件是否放在了 `profiles/web/` 下 |
| 打开地址提示证书错误 | 管理台 DNS 里 HTTPS Certificates 没开，开了之后等 1~2 分钟再试 |
| 想换机器名（不想叫 dsh） | 改 compose 里 `hostname:`，同时改 serve.json 和 cordis.patch.yml 里的域名 |

## 切回 Caddy 版（以后想换回来）

1. Docker → 项目 → 停掉 Tailscale 项目；
2. 用根目录的 `docker-compose.yml` 重新创建项目（Caddy 版，需 3443 入站通，可用 `https://NAS-IP:3443`）；
3. `cordis.patch.yml` 里 connection 那条**可以留着**（无副作用），也可以删掉只留 webserver 条目。
