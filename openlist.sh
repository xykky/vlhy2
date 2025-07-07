#!/bin/bash

set -e

# 配置变量：修改为你的实际域名
DOMAIN="openlist.sizz.dpdns.org"

# 安装 Docker
echo "正在安装 Docker..."
curl -fsSL https://get.docker.com | sh

# 运行 Openlist 容器
echo "正在部署 Openlist 容器..."
docker run -d --restart=unless-stopped \
  -v /etc/openlist:/opt/openlist/data \
  -p 5244:5244 \
  -e PUID=0 -e PGID=0 -e UMASK=022 \
  --name="openlist" \
  xiguanle/openlist:latest

# 安装 Nginx
echo "正在安装 Nginx..."
apt update
apt install nginx -y

# 配置 Nginx 反向代理
echo "配置 Nginx 反向代理..."
cat > /etc/nginx/sites-available/openlist <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:5244;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -s /etc/nginx/sites-available/openlist /etc/nginx/sites-enabled/
systemctl reload nginx
systemctl enable nginx
systemctl start nginx

# 安装 Certbot
echo "正在安装 Certbot..."
apt install -y certbot python3-certbot-nginx

# 申请 HTTPS 证书
echo "申请 Let's Encrypt HTTPS 证书..."
certbot --nginx -d $DOMAIN --agree-tos --email xykqaq@163.com --non-interactive

echo "✅ 部署完成！请访问：https://$DOMAIN"
