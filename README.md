# dt-webm

`dt-webm` 是一个面向 Linux 服务器的交互式命令行工具，整合了：

- **GoAccess**：Web 日志统计与可视化报告
- **CrowdSec**：攻击检测、自动封禁与封禁管理

目标是以轻量、可维护、全中文交互的方式，提供一套开箱即用的服务器安全运维脚本。

---

## 核心特性

- **环境自适应**
  - 自动识别 `apt`（Ubuntu/Debian）与 `dnf/yum`（RHEL/CentOS/AlmaLinux/Rocky）
- **依赖闭环安装**
  - 自动检查 `goaccess` 与 `crowdsec`
  - 提供一键逐步安装（含 CrowdSec 仓库、核心组件、`nftables` bouncer）
- **全局命令注册**
  - `install` 指令可自动软链接到 `/usr/local/bin/dt-webm`
  - 提供独立 `install.sh` 一键安装脚本
- **安全保护**
  - 自动探测当前 SSH 登录 IP，写入 CrowdSec 白名单（防误封）
  - 默认防火墙建议放行端口：`22,80,443`
  - 支持自定义端口白名单（持久化配置）
  - 使用 `setfacl` 赋予 `crowdsec` 用户日志目录 `rx` 权限，不破坏原有 `chmod`
- **日志路径智能发现**
  - 自动扫描 `/var/log/nginx`、`/var/log/httpd`
  - 失败时可手动输入并保存到配置文件
- **GoAccess 统计模块**
  - 强制中文界面：`--language=zh_CN`（版本不支持时自动降级）
  - 支持 **COMBINED** 与 **Nginx Proxy Manager** 默认 proxy 日志（`%v` 虚拟主机域名、`[Client %h]` 客户端 IP；`log-format` 在脚本内用单引号定义，避免 `[]` 转义问题）
  - 支持快捷时间切片：过去 1 小时、今天、昨天
  - 支持自定义时间段：`YYYYMMDD_HHMMSS-YYYYMMDD_HHMMSS`
  - 时间切片采用 **epoch 严格比较**，并支持按日志时区偏移（如 `+0800`）修正
- **CrowdSec 安全模块**
  - 攻击告警查看：`cscli alerts list`
  - 封禁管理：查看、手动封禁（IP/CIDR 校验）、交互解封
- **Webhook 告警推送**
  - 支持钉钉 / 飞书 / Telegram
  - 支持事件去重与状态缓存，避免重复推送
  - 支持告警（alerts）与决策（decisions）双通道推送
- **GeoIP 自动维护**
  - 支持月度定时更新 `.mmdb` 数据库（需配置 `GEOIP_URL`）

---

## 目录结构

- `dt-webm`：主脚本（本地开发）
- `install.sh`：独立一键安装脚本
- `README.md`：项目说明文档

---

## 快速开始

> 建议在 Linux 服务器（root 或 sudo）下执行。

### 方式一：一键安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/coderjia/dt-webm/main/install.sh | sudo bash
```

安装器会自动完成：

- root 与 `curl` 环境检查
- 下载仓库 `dt-webm` 到临时目录并安装到 `/usr/local/bin/dt-webm`
- 自动检测 `/usr/local/bin` 是否在 PATH 中（不在则写入 `/etc/profile.d/dt-webm-path.sh`）
- 初始化 `/etc/dt-webm/config.conf`
- 自动探测 SSH IP 写入 CrowdSec 白名单（若 `cscli` 可用）
- 交互输入自定义端口（逗号分隔，回车跳过）

### 方式二：本地脚本运行

```bash
chmod +x ./dt-webm
sudo ./dt-webm install
```

安装完成后，全局调用：

```bash
dt-webm
```

常用子命令：

```bash
dt-webm install       # 注册全局命令并初始化依赖与定时任务
dt-webm geoip-update  # 手动更新 GeoIP 数据库
dt-webm metrics       # CrowdSec 运行指标（cscli metrics 子菜单）
dt-webm self-update   # 自更新主程序（可选 GitHub / Gitee，需确认）
```

---

## 配置文件

默认配置文件路径：

`/etc/dt-webm/config.conf`

首次运行会自动创建并写入默认项，典型内容如下：

```bash
# dt-webm 配置文件
# Web 日志目录（自动发现失败时可手工配置）
LOG_DIR=""
# Webhook 类型：dingtalk / feishu / telegram
WEBHOOK_TYPE=""
# Webhook URL（钉钉/飞书/Telegram Bot API）
WEBHOOK_URL=""
# GeoIP 数据库下载地址（DB-IP 或 MaxMind 直链）
GEOIP_URL=""
# 防火墙建议放行端口（逗号分隔）
ALLOW_PORTS="22,80,443"
```

---

## 菜单功能

运行 `dt-webm` 后可使用：

- 依赖检查与安装
- GoAccess 日志统计
- CrowdSec 攻击警报
- CrowdSec 运行指标（`cscli metrics`，含 JSON/帮助/自定义参数）
- CrowdSec 封禁管理
- Webhook 配置
- 端口白名单配置
- 更新 GeoIP 数据库
- 配置 GeoIP 月度任务
- 配置告警推送任务
- 安装全局命令（install）
- 程序自更新（可选 GitHub / Gitee 拉取最新 `dt-webm` 覆盖当前安装路径，需确认）

---

## 时间切片说明

支持以下时间模式：

- `过去 1 小时`
- `今天`
- `昨天`
- 自定义：`20260401_000000-20260403_120000`

脚本会将日志行时间解析为 epoch 进行比较，且在日志包含时区字段（如 `+0800`）时自动换算，适合跨时区部署场景。

### GoAccess 与 Nginx Proxy Manager

统计菜单中可选择 **Nginx Proxy Manager** 或 **自动检测**（首行含 `[Client` 则按 NPM 解析）。典型 NPM proxy 行形如：

`[10/Apr/2026:08:12:49 +0000] - 200 200 - GET https example.com "/api/" [Client 1.2.3.4] [Length 61] ...`

对应 GoAccess 使用 `--date-format=%d/%b/%Y`、`--time-format="%H:%M:%S %z"`，与行首时间戳一致。若你的 NPM 在 `[Gzip …]` / `[Sent-to …]` 段字段数量与默认不同，可改选 **COMBINED** 或自行调整脚本内 `GOACCESS_NPM_LOG_FORMAT`（单引号包裹整段 `log-format`）。

---

## Webhook 去重与状态缓存

推送脚本：`/usr/local/bin/dt-webm-webhook.sh`

状态文件目录：`/var/lib/dt-webm`

- `webhook-state.db`：已推送事件签名缓存
- `webhook-state.lock`：并发锁文件（若系统有 `flock`）

特性：

- 仅推送未发送过的事件（去重）
- 每轮处理最新 20 条记录（告警/决策）
- 状态文件自动裁剪（保留最近 2000 条）

---

## 定时任务

- GeoIP 月度更新（每月 1 日 03:00）
- Webhook 告警检查（每 5 分钟）

脚本会自动写入 `crontab` 并带标记，便于重复执行时覆盖更新。

---

## 常见问题

- **Q: 为什么没有生成 GoAccess 报告？**  
  A: 请确认 `goaccess` 已安装，并在菜单中选择与日志一致的格式（**COMBINED** 或 **Nginx Proxy Manager** / 自动检测）。NPM 日志请勿选错为 COMBINED。

- **Q: 为什么没有收到 Webhook 推送？**  
  A: 检查 `WEBHOOK_URL` 是否可达、`cscli` 是否能返回 JSON、以及是否被去重机制过滤。

- **Q: 如何自定义防火墙建议端口？**  
  A: 在菜单中选择“端口白名单配置”，或直接修改 `ALLOW_PORTS`。

---

## 免责声明

本项目为运维自动化脚本，请先在测试环境验证后再用于生产环境。涉及防火墙、封禁与日志权限调整时，请确保有可靠的回滚与控制台访问方案。
