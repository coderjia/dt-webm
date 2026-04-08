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
- **安全保护**
  - 自动探测当前 SSH 登录 IP，写入 CrowdSec 白名单（防误封）
  - 默认防火墙建议放行端口：`22,80,443,28866`
  - 支持自定义端口白名单（持久化配置）
  - 使用 `setfacl` 赋予 `crowdsec` 用户日志目录 `rx` 权限，不破坏原有 `chmod`
- **日志路径智能发现**
  - 自动扫描 `/var/log/nginx`、`/var/log/httpd`
  - 失败时可手动输入并保存到配置文件
- **GoAccess 统计模块**
  - 强制中文界面：`--language=zh_CN`
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

- `dt-webm`：主脚本
- `README.md`：项目说明文档

---

## 快速开始

> 建议在 Linux 服务器（root 或 sudo）下执行。

```bash
chmod +x ./dt-webm
sudo ./dt-webm install
```

安装完成后，可全局调用：

```bash
dt-webm
```

---

## 配置文件

默认配置文件路径：

`/etc/dt-webm/config.conf`

首次运行会自动创建并写入默认项，典型内容如下：

```bash
# dt-webm 配置文件
LOG_DIR=""
WEBHOOK_TYPE=""
WEBHOOK_URL=""
GEOIP_URL=""
ALLOW_PORTS="22,80,443,28866"
```

---

## 菜单功能

运行 `dt-webm` 后可使用：

- 依赖检查与安装
- GoAccess 日志统计
- CrowdSec 攻击警报
- CrowdSec 封禁管理
- Webhook 配置
- 端口白名单配置
- 更新 GeoIP 数据库
- 配置 GeoIP 月度任务
- 配置告警推送任务
- 安装全局命令（install）

---

## 时间切片说明

支持以下时间模式：

- `过去 1 小时`
- `今天`
- `昨天`
- 自定义：`20260401_000000-20260403_120000`

脚本会将日志行时间解析为 epoch 进行比较，且在日志包含时区字段（如 `+0800`）时自动换算，适合跨时区部署场景。

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
  A: 请先确认日志路径与日志格式是否为 COMBINED，且 `goaccess` 已安装。

- **Q: 为什么没有收到 Webhook 推送？**  
  A: 检查 `WEBHOOK_URL` 是否可达、`cscli` 是否能返回 JSON、以及是否被去重机制过滤。

- **Q: 如何自定义防火墙建议端口？**  
  A: 在菜单中选择“端口白名单配置”，或直接修改 `ALLOW_PORTS`。

---

## 免责声明

本项目为运维自动化脚本，请先在测试环境验证后再用于生产环境。涉及防火墙、封禁与日志权限调整时，请确保有可靠的回滚与控制台访问方案。
