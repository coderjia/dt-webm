#!/usr/bin/env bash
set -e

REPO_RAW_BASE="https://raw.githubusercontent.com/coderjia/dt-webm/main"
MAIN_SCRIPT_URL="${REPO_RAW_BASE}/dt-webm.sh"
TARGET_BIN="/usr/local/bin/dt-webm"
CONFIG_DIR="/etc/dt-webm"
CONFIG_FILE="${CONFIG_DIR}/config.conf"

COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_BLUE='\033[0;34m'
COLOR_YELLOW='\033[1;33m'
COLOR_RESET='\033[0m'

title() { echo -e "${COLOR_BLUE}==== $* ====${COLOR_RESET}"; }
ok() { echo -e "${COLOR_GREEN}[成功]${COLOR_RESET} $*"; }
warn() { echo -e "${COLOR_RED}[警告]${COLOR_RESET} $*"; }
info() { echo -e "${COLOR_YELLOW}[提示]${COLOR_RESET} $*"; }

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    warn "请使用 root 权限执行安装脚本。"
    exit 1
  fi
}

check_curl() {
  if ! command -v curl >/dev/null 2>&1; then
    warn "未检测到 curl，请先安装 curl 后重试。"
    exit 1
  fi
}

ensure_usr_local_bin_in_path() {
  case ":${PATH}:" in
    *:/usr/local/bin:*)
      ok "当前 PATH 已包含 /usr/local/bin"
      ;;
    *)
      info "当前 PATH 未包含 /usr/local/bin，正在写入 /etc/profile.d/dt-webm-path.sh"
      cat > /etc/profile.d/dt-webm-path.sh <<'EOF'
#!/usr/bin/env sh
case ":${PATH}:" in
  *:/usr/local/bin:*) ;;
  *) export PATH="/usr/local/bin:${PATH}" ;;
esac
EOF
      chmod +x /etc/profile.d/dt-webm-path.sh
      ok "已添加 PATH 兜底配置，重新登录后生效。"
      ;;
  esac
}

download_and_install_main() {
  title "下载并安装主程序"
  tmp_file="$(mktemp /tmp/dt-webm.XXXXXX)"
  curl -fsSL "${MAIN_SCRIPT_URL}" -o "${tmp_file}"
  if [ ! -s "${tmp_file}" ]; then
    warn "主程序下载失败：${MAIN_SCRIPT_URL}"
    exit 1
  fi

  mv "${tmp_file}" "${TARGET_BIN}"
  chmod +x "${TARGET_BIN}"
  ok "主程序已安装到 ${TARGET_BIN}"
}

init_config_file() {
  title "初始化配置文件"
  mkdir -p "${CONFIG_DIR}"
  if [ ! -f "${CONFIG_FILE}" ]; then
    cat > "${CONFIG_FILE}" <<'EOF'
# dt-webm 配置文件
LOG_DIR=""
WEBHOOK_TYPE=""
WEBHOOK_URL=""
GEOIP_URL=""
ALLOW_PORTS="22,80,443"
EOF
    ok "已创建默认配置：${CONFIG_FILE}"
  else
    if ! grep -q '^ALLOW_PORTS=' "${CONFIG_FILE}" 2>/dev/null; then
      echo 'ALLOW_PORTS="22,80,443"' >> "${CONFIG_FILE}"
    fi
    ok "配置文件已存在，已完成兼容性检查。"
  fi
}

normalize_ports() {
  raw="$1"
  cleaned="$(echo "${raw}" | tr -d ' ')"
  [ -n "${cleaned}" ] || return 1
  IFS=',' read -r -a arr <<< "${cleaned}"
  out=""
  for p in "${arr[@]}"; do
    if ! echo "${p}" | grep -Eq '^[0-9]+$'; then
      return 1
    fi
    if [ "${p}" -lt 1 ] || [ "${p}" -gt 65535 ]; then
      return 1
    fi
    if [ -z "${out}" ]; then
      out="${p}"
    else
      case ",${out}," in
        *,"${p}",*) ;;
        *) out="${out},${p}" ;;
      esac
    fi
  done
  echo "${out}"
}

set_config_kv() {
  key="$1"
  val="$2"
  if grep -q "^${key}=" "${CONFIG_FILE}" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=\"${val}\"|g" "${CONFIG_FILE}"
  else
    echo "${key}=\"${val}\"" >> "${CONFIG_FILE}"
  fi
}

ask_custom_ports() {
  title "端口配置"
  info "默认建议放行端口为：22,80,443"
  info "如需增加自定义端口，请输入（逗号分隔，如 8443,28866），直接回车则跳过。"
  read -r custom_ports
  if [ -z "${custom_ports}" ]; then
    ok "已跳过自定义端口配置，保持默认端口。"
    return
  fi

  normalized="$(normalize_ports "${custom_ports}" || true)"
  if [ -z "${normalized}" ]; then
    warn "自定义端口格式非法，已跳过。"
    return
  fi

  base="22,80,443"
  merged="${base}"
  IFS=',' read -r -a p_arr <<< "${normalized}"
  for p in "${p_arr[@]}"; do
    case ",${merged}," in
      *,"${p}",*) ;;
      *) merged="${merged},${p}" ;;
    esac
  done
  set_config_kv "ALLOW_PORTS" "${merged}"
  ok "已保存端口配置：${merged}"
}

get_ssh_ip() {
  ip_from_conn="$(echo "${SSH_CONNECTION:-}" | awk "{print \$1}")"
  if [ -n "${ip_from_conn}" ]; then
    echo "${ip_from_conn}"
    return
  fi
  who_ip="$(who | awk "NR==1{gsub(/[()]/,\"\",\$5);print \$5}")"
  echo "${who_ip:-}"
}

write_crowdsec_whitelist() {
  title "自杀保护白名单"
  if ! command -v cscli >/dev/null 2>&1; then
    info "未检测到 cscli，跳过 CrowdSec 白名单写入。"
    return
  fi

  ssh_ip="$(get_ssh_ip)"
  if [ -z "${ssh_ip}" ]; then
    info "未检测到当前 SSH 登录 IP，跳过白名单写入。"
    return
  fi

  mkdir -p /etc/crowdsec/parsers/s02-enrich/
  wl_file="/etc/crowdsec/parsers/s02-enrich/dt-webm-whitelist.yaml"
  cat > "${wl_file}" <<EOF
name: dt-webm/self-whitelist
description: "dt-webm 自动白名单"
whitelist:
  reason: "当前 SSH 登录 IP 防误封"
  ip:
    - "${ssh_ip}"
EOF
  if [ $? -eq 0 ]; then
    ok "已写入 CrowdSec 白名单 IP：${ssh_ip}"
    systemctl restart crowdsec >/dev/null 2>&1 || true
  else
    warn "写入 CrowdSec 白名单失败。"
  fi
}

main() {
  title "dt-webm 一键安装"
  require_root
  check_curl
  ensure_usr_local_bin_in_path
  download_and_install_main
  init_config_file
  ask_custom_ports
  write_crowdsec_whitelist

  echo
  ok "安装完成。"
  info "调用方式："
  echo "  1) 交互菜单：dt-webm"
  echo "  2) 全局安装流程：dt-webm install"
  echo "  3) GeoIP 更新：dt-webm geoip-update"
  info "防火墙请放行端口：$(grep '^ALLOW_PORTS=' "${CONFIG_FILE}" | sed 's/ALLOW_PORTS=//;s/\"//g')"
}

main "$@"
