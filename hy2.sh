#!/bin/bash
set -e

# =============== [ 配置区域 - 修改这些 ] ================
DOMAIN="voxl.dpdns.org"               # 主域名
SUB_DOMAIN="hy2.voxl.dpdns.org"       # 子域名用于跳端口
EMAIL="xykqaq@163.com"                # 用于 TLS 申请
CF_API_TOKEN="eelonLyHiuYTzUQJxeS3YXPQl1No-WlxmScUe8TZ"  # Cloudflare API Token
CF_ZONE_ID="af301abf2df0002be8e89867c8f431bb"  # Cloudflare Zone ID
PORT_MIN=20000
PORT_MAX=30000
# ========================================================

CERT_DIR="/etc/hysteria"
BIN_PATH="/usr/local/bin/hysteria"
CONFIG_PATH="${CERT_DIR}/config.yaml"
SERVICE_FILE="/etc/systemd/system/hysteria.service"
CRON_FILE="/etc/cron.d/hysteria-jump"
WEB_SUB_DIR="/var/www/html/hy2_sub"

generate_random() {
  PASS=$(openssl rand -hex 8)
  OBFS_PASS=$(openssl rand -hex 8)
  PORT=$(shuf -i ${PORT_MIN}-${PORT_MAX} -n 1)
}

install_dependencies() {
  apt update -y
  apt install -y curl wget socat unzip jq nginx
}

install_acme_sh() {
  if ! command -v acme.sh &> /dev/null; then
    curl https://get.acme.sh | sh
    source ~/.bashrc
  fi
}

issue_cert() {
  ~/.acme.sh/acme.sh --issue -d ${SUB_DOMAIN} --standalone --keylength ec-256 --force
  mkdir -p ${CERT_DIR}
  ~/.acme.sh/acme.sh --install-cert -d ${SUB_DOMAIN} --ecc \
    --key-file ${CERT_DIR}/private.key \
    --fullchain-file ${CERT_DIR}/cert.pem
}

download_hysteria() {
  LATEST=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep browser_download_url | grep linux-amd64 | grep server | cut -d '"' -f 4)
  mkdir -p /tmp/hysteria && cd /tmp/hysteria
  wget -q $LATEST -O hysteria.tar.gz
  tar -zxf hysteria.tar.gz
  mv hysteria ${BIN_PATH}
  chmod +x ${BIN_PATH}
}

write_config() {
  cat >${CONFIG_PATH} <<EOF
listen: :${PORT}
tls:
  cert: ${CERT_DIR}/cert.pem
  key: ${CERT_DIR}/private.key
auth:
  type: password
  password: "${PASS}"
obfs:
  type: salamander
  salamander:
    password: "${OBFS_PASS}"
bandwidth:
  up: 1000 mbps
  down: 1000 mbps
EOF
}

write_service() {
  cat >${SERVICE_FILE} <<EOF
[Unit]
Description=Hysteria2 Server
After=network.target

[Service]
ExecStart=${BIN_PATH} server -c ${CONFIG_PATH}
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF
}

start_service() {
  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl enable hysteria
  systemctl restart hysteria
}

update_cf_dns() {
  echo "更新 Cloudflare DNS..."

  DNS_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?name=${SUB_DOMAIN}" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')

  if [ -z "$DNS_ID" ] || [ "$DNS_ID" == "null" ]; then
    echo "请先在 Cloudflare 添加 ${SUB_DOMAIN} 的 A 记录"
    exit 1
  fi

  curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${DNS_ID}" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"${SUB_DOMAIN}\",\"content\":\"$(curl -s ifconfig.me)\",\"ttl\":120,\"proxied\":true}" >/dev/null

  # SRV record
  SRV_NAME="_hysteria._udp.${SUB_DOMAIN}"
  SRV_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?name=${SRV_NAME}" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')

  SRV_DATA="{\"type\":\"SRV\",\"name\":\"${SRV_NAME}\",\"data\":{\"service\":\"_hysteria\",\"proto\":\"_udp\",\"name\":\"${SUB_DOMAIN}\",\"priority\":10,\"weight\":10,\"port\":${PORT},\"target\":\"${SUB_DOMAIN}\"},\"ttl\":120,\"proxied\":false}"

  if [ -z "$SRV_ID" ] || [ "$SRV_ID" == "null" ]; then
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
      -H "Authorization: Bearer ${CF_API_TOKEN}" -H "Content-Type: application/json" \
      --data "$SRV_DATA" >/dev/null
  else
    curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${SRV_ID}" \
      -H "Authorization: Bearer ${CF_API_TOKEN}" -H "Content-Type: application/json" \
      --data "$SRV_DATA" >/dev/null
  fi
}

generate_subscribe_files() {
  mkdir -p ${WEB_SUB_DIR}
  HY2_LINK="hy2://${PASS}@${SUB_DOMAIN}:${PORT}?obfs=salamander&obfs-password=${OBFS_PASS}&sni=bing.com&alpn=h3#HY2-${SUB_DOMAIN}"

  echo "${HY2_LINK}" > ${WEB_SUB_DIR}/hy2.txt

  cat >${WEB_SUB_DIR}/hy2.yaml <<EOF
proxies:
- name: HY2-${SUB_DOMAIN}
  type: hysteria2
  server: ${SUB_DOMAIN}
  port: ${PORT}
  password: ${PASS}
  obfs: salamander
  obfs-password: ${OBFS_PASS}
  sni: bing.com
  alpn:
    - h3
  skip-cert-verify: true
EOF
}

setup_cron() {
  echo "设置每日自动跳端口任务..."
  cat >${CRON_FILE} <<EOF
0 4 * * * root /bin/bash $(realpath $0) >> /var/log/hysteria-jump.log 2>&1
EOF
  chmod 644 ${CRON_FILE}
  systemctl restart cron || service cron restart
}

output_summary() {
  echo ""
  echo "=== ✅ 安装完成，节点信息如下："
  echo "域名：${SUB_DOMAIN}"
  echo "端口：${PORT}"
  echo "密码：${PASS}"
  echo "混淆密码：${OBFS_PASS}"
  echo ""
  echo "▶ v2rayN 订阅地址（hy2://）："
  echo "https://${SUB_DOMAIN}/hy2_sub/hy2.txt"
  echo ""
  echo "▶ Clash 订阅地址（yaml）："
  echo "https://${SUB_DOMAIN}/hy2_sub/hy2.yaml"
  echo ""
  echo "✅ 脚本已自动添加每天凌晨 4 点跳端口"
  echo ""
}

main() {
  install_dependencies
  generate_random
  install_acme_sh
  issue_cert
  download_hysteria
  write_config
  write_service
  start_service
  update_cf_dns
  generate_subscribe_files
  setup_cron
  output_summary
}

main
