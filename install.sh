#!/bin/bash

# WebDAV 安装路径
WEBDAV_DIR="/var/www/webdav"
CONFIG_FILE="/etc/nginx/webdav.htpasswd"

# 颜色
GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

# 证书路径
SSL_CERT="/etc/letsencrypt/live/yourdomain.com/fullchain.pem"
SSL_KEY="/etc/letsencrypt/live/yourdomain.com/privkey.pem"

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}请使用 root 用户运行此脚本！${RESET}"
    exit 1
fi

# 安装 WebDAV 和所需依赖
install_webdav() {
    echo -e "${GREEN}安装 WebDAV 并启用 SSL...${RESET}"
    apt update && apt install -y nginx apache2-utils certbot python3-certbot-nginx

    mkdir -p "$WEBDAV_DIR"
    chmod 777 "$WEBDAV_DIR"

    # 设置 Nginx 配置
    cat > /etc/nginx/sites-available/webdav <<EOF
server {
    listen 80;
    server_name yourdomain.com;
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name yourdomain.com;

    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_KEY;

    location / {
        auth_basic "WebDAV Secure Area";
        auth_basic_user_file $CONFIG_FILE;
        root $WEBDAV_DIR;
        autoindex on;
        dav_methods PUT DELETE MKCOL COPY MOVE;
        dav_ext_methods PROPFIND OPTIONS;
    }
}
EOF

    ln -s /etc/nginx/sites-available/webdav /etc/nginx/sites-enabled/webdav
    systemctl restart nginx
    echo -e "${GREEN}WebDAV 安装完成！${RESET}"
}

# 配置 SSL 证书
setup_ssl() {
    echo -e "${GREEN}申请 SSL 证书...${RESET}"
    certbot --nginx -d yourdomain.com
    systemctl reload nginx
}

# 添加用户
add_user() {
    echo -e "${GREEN}请输入要添加的用户名:${RESET}"
    read username
    htpasswd -c "$CONFIG_FILE" "$username"
    systemctl restart nginx
    echo -e "${GREEN}用户 $username 添加成功！${RESET}"
}

# 删除用户
delete_user() {
    echo -e "${GREEN}请输入要删除的用户名:${RESET}"
    read username
    htpasswd -D "$CONFIG_FILE" "$username"
    systemctl restart nginx
    echo -e "${GREEN}用户 $username 已删除！${RESET}"
}

# 修改密码
change_password() {
    echo -e "${GREEN}请输入要修改密码的用户名:${RESET}"
    read username
    htpasswd "$CONFIG_FILE" "$username"
    systemctl restart nginx
    echo -e "${GREEN}用户 $username 的密码已更新！${RESET}"
}

# 主菜单
while true; do
    echo -e "${GREEN}====== WebDAV 管理面板 ======${RESET}"
    echo "1. 安装 WebDAV 并启用 SSL"
    echo "2. 申请 SSL 证书"
    echo "3. 添加用户"
    echo "4. 删除用户"
    echo "5. 修改用户密码"
    echo "6. 退出"
    read -p "请选择操作 (1-6): " choice

    case $choice in
        1) install_webdav ;;
        2) setup_ssl ;;
        3) add_user ;;
        4) delete_user ;;
        5) change_password ;;
        6) exit 0 ;;
        *) echo -e "${RED}无效选择，请重新输入！${RESET}" ;;
    esac
done
