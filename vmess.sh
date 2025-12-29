#!/bin/bash

# =========================
# Sing-box VMess + Argo (带菜单 + 优选域名管理)
# 快捷指令: vmess
# =========================

export LANG=en_US.UTF-8
re="\033[0m"
red="\033[1;91m"
green="\e[1;32m"
yellow="\e[1;33m"
purple="\e[1;35m"
skyblue="\e[1;36m"

# 定义变量
work_dir="/etc/vmess-box"
config_dir="${work_dir}/config.json"
cfip_file="${work_dir}/cfip.conf"
service_core="vmess-box"
service_argo="vmess-argo"

# 检查 root 权限
[[ $EUID -ne 0 ]] && echo -e "${red}错误: 请在 root 用户下运行脚本${re}" && exit 1

# 检查服务状态
check_status() {
    if systemctl is-active --quiet $service_core && systemctl is-active --quiet $service_argo; then
        echo -e "${green}运行中 (Running)${re}"
        return 0
    else
        echo -e "${red}未运行 (Stopped)${re}"
        return 1
    fi
}

# 获取 IPv4 (强制)
get_realip() {
    ip=$(curl -4 -sm 2 ip.sb)
    if [ -z "$ip" ]; then ip=$(curl -4 -sm 2 ipinfo.io/ip); fi
    if [ -z "$ip" ]; then ip=$(curl -4 -sm 2 ifconfig.me); fi
    echo "$ip"
}

# 创建快捷指令
create_shortcut() {
    cp "$0" /usr/bin/vmess
    chmod +x /usr/bin/vmess
    echo -e "${green}快捷指令 'vmess' 已创建/更新。${re}"
}

# 安装依赖
install_dependencies() {
    echo -e "${yellow}正在检查并安装依赖...${re}"
    if [ -f /etc/debian_version ]; then
        apt update -y && apt install -y curl jq tar openssl
    elif [ -f /etc/redhat-release ]; then
        yum install -y curl jq tar openssl
    elif [ -f /etc/alpine-release ]; then
        apk update && apk add curl jq tar openssl
    else
        echo -e "${red}不支持的系统!${re}" && exit 1
    fi
}

# 安装核心
install_core() {
    ARCH_RAW=$(uname -m)
    case "${ARCH_RAW}" in
        'x86_64') ARCH='amd64' ;;
        'x86' | 'i686' | 'i386') ARCH='386' ;;
        'aarch64' | 'arm64') ARCH='arm64' ;;
        *) echo -e "${red}不支持的架构: ${ARCH_RAW}${re}"; exit 1 ;;
    esac

    echo -e "${purple}下载组件中...${re}"
    mkdir -p "${work_dir}" && chmod 777 "${work_dir}"
    curl -sLo "${work_dir}/sing-box" "https://$ARCH.ssss.nyc.mn/sbx"
    curl -sLo "${work_dir}/argo" "https://$ARCH.ssss.nyc.mn/bot"
    
    if [ ! -f "${work_dir}/sing-box" ]; then
        echo -e "${red}下载失败，请检查网络${re}" && exit 1
    fi
    chmod +x "${work_dir}/sing-box" "${work_dir}/argo"
    
    # 初始化优选域名配置
    if [ ! -f "$cfip_file" ]; then
        echo "cf.877774.xyz:443" > "$cfip_file"
    fi
}

# 生成配置
configure() {
    uuid=$(cat /proc/sys/kernel/random/uuid)
    cat > "${config_dir}" << EOF
{
  "log": { "disabled": false, "level": "error", "output": "$work_dir/sb.log", "timestamp": true },
  "inbounds": [
    {
      "type": "vmess", "tag": "vmess-ws", "listen": "127.0.0.1", "listen_port": 8001,
      "users": [{ "uuid": "$uuid" }],
      "transport": { "type": "ws", "path": "/vmess-argo", "early_data_header_name": "Sec-WebSocket-Protocol" }
    }
  ],
  "outbounds": [
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ]
}
EOF
}

# 配置服务
setup_service() {
    cat > /etc/systemd/system/${service_core}.service << EOF
[Unit]
Description=Sing-box VMess Service
After=network.target
[Service]
User=root
WorkingDirectory=$work_dir
ExecStart=$work_dir/sing-box run -c $config_dir
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity
[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/${service_argo}.service << EOF
[Unit]
Description=Cloudflare Tunnel for VMess
After=network.target
[Service]
Type=simple
NoNewPrivileges=yes
TimeoutStartSec=0
ExecStart=/bin/sh -c "$work_dir/argo tunnel --url http://127.0.0.1:8001 --no-autoupdate --edge-ip-version auto --protocol http2 > $work_dir/argo.log 2>&1"
Restart=on-failure
RestartSec=5s
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ${service_core} ${service_argo}
    systemctl restart ${service_core} ${service_argo}
}

# 修改优选域名
change_cfip() {
    clear
    echo -e "${yellow}=== 修改 VMess 优选域名 (CFIP) ===${re}"
    echo -e "${green}1.${re} cf.090227.xyz"
    echo -e "${green}2.${re} cf.877774.xyz (默认)"
    echo -e "${green}3.${re} cf.877771.xyz"
    echo -e "${green}4.${re} cdns.doon.eu.org"
    echo -e "${green}5.${re} cf.zhetengsha.eu.org"
    echo -e "${green}6.${re} time.is"
    echo -e "${purple}------------------------${re}"
    echo -e "请输入选项 (1-6)，或者直接输入 ${skyblue}域名:端口${re} (例如: 1.1.1.1:443)"
    echo -e "直接回车默认使用选项 2"
    echo -e ""
    read -p "请输入: " cfip_input

    if [ -z "$cfip_input" ]; then
        cfip="cf.877774.xyz"
        cfport="443"
    else
        case "$cfip_input" in
            "1") cfip="cf.090227.xyz"; cfport="443" ;;
            "2") cfip="cf.877774.xyz"; cfport="443" ;;
            "3") cfip="cf.877771.xyz"; cfport="443" ;;
            "4") cfip="cdns.doon.eu.org"; cfport="443" ;;
            "5") cfip="cf.zhetengsha.eu.org"; cfport="443" ;;
            "6") cfip="time.is"; cfport="443" ;;
            *)
                if [[ "$cfip_input" =~ : ]]; then
                    cfip=$(echo "$cfip_input" | cut -d':' -f1)
                    cfport=$(echo "$cfip_input" | cut -d':' -f2)
                else
                    cfip="$cfip_input"
                    cfport="443"
                fi
                ;;
        esac
    fi

    # 保存配置到文件
    echo "${cfip}:${cfport}" > "$cfip_file"
    echo -e "${green}优选域名已更新为: ${purple}${cfip}:${cfport}${re}"
    echo -e "${yellow}正在重新生成订阅链接...${re}"
    show_node_info
}

# 提取并显示链接
show_node_info() {
    # 如果是刚启动，多等一会
    [ "$1" == "wait" ] && echo -e "${yellow}正在获取 Cloudflare 域名...${re}" && sleep 5

    for i in {1..5}; do
        if [ -f "${work_dir}/argo.log" ]; then
            argodomain=$(sed -n 's|.*https://\([^/]*trycloudflare\.com\).*|\1|p' "${work_dir}/argo.log" | head -n 1)
        fi
        [ -n "$argodomain" ] && break
        sleep 2
    done

    if [ -z "$argodomain" ]; then
        echo -e "${red}获取 Argo 域名失败，服务可能未启动或网络问题。${re}"
        return
    fi

    # 读取 UUID
    if [ -f "$config_dir" ]; then
        uuid=$(grep "uuid" $config_dir | awk -F'"' '{print $4}')
    else
        echo -e "${red}配置文件不存在${re}" && return
    fi

    # 读取优选 IP 配置
    if [ -f "$cfip_file" ]; then
        CF_FULL=$(cat "$cfip_file")
        CFIP=${CF_FULL%:*}
        CFPORT=${CF_FULL#*:}
    else
        CFIP='cf.877774.xyz'
        CFPORT='443'
    fi

    VMESS_JSON="{ \"v\": \"2\", \"ps\": \"VMess-Argo\", \"add\": \"${CFIP}\", \"port\": \"${CFPORT}\", \"id\": \"${uuid}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"${argodomain}\", \"path\": \"/vmess-argo?ed=2560\", \"tls\": \"tls\", \"sni\": \"${argodomain}\", \"alpn\": \"\", \"fp\": \"firefox\", \"allowlnsecure\": \"false\"}"
    VMESS_LINK="vmess://$(echo -n "$VMESS_JSON" | base64 -w0)"

    echo -e ""
    echo -e "${green}=== 节点信息 ===${re}"
    echo -e "${skyblue}优选地址:${re} ${CFIP}:${CFPORT}"
    echo -e "${skyblue}Argo域名:${re} ${argodomain}"
    echo -e "${skyblue}UUID:${re}     ${uuid}"
    echo -e ""
    echo -e "${purple}VMess 链接:${re}"
    echo -e "${green}${VMESS_LINK}${re}"
    echo -e ""
}

# 安装流程
install_main() {
    install_dependencies
    install_core
    configure
    setup_service
    create_shortcut
    echo -e "${green}安装完成！${re}"
    show_node_info "wait"
}

# 重置域名 (临时救急)
refresh_domain() {
    echo -e "${yellow}正在重启 Argo 通道以获取新域名...${re}"
    systemctl restart ${service_argo}
    sleep 2
    echo -e "${yellow}等待新域名生效...${re}"
    show_node_info "wait"
}

# 卸载
uninstall() {
    echo -e "${yellow}正在卸载...${re}"
    systemctl stop ${service_core} ${service_argo}
    systemctl disable ${service_core} ${service_argo}
    rm /etc/systemd/system/${service_core}.service /etc/systemd/system/${service_argo}.service
    systemctl daemon-reload
    rm -rf ${work_dir}
    rm /usr/bin/vmess
    echo -e "${green}卸载完成。${re}"
    exit 0
}

# 菜单
menu() {
    clear
    echo -e "${purple}==================================${re}"
    echo -e "${purple}   VMess + Argo 管理脚本 (IPv4)   ${re}"
    echo -e "${purple}==================================${re}"
    echo -e "当前状态: $(check_status)"
    echo -e ""
    echo -e "${green}1.${re} 安装 / 重装服务"
    echo -e "${green}2.${re} 查看节点链接 (VMess)"
    echo -e "${green}3.${re} 重置域名 (救急用 - 域名失效点我)"
    echo -e "${green}4.${re} 修改优选域名 (CFIP)"
    echo -e "${purple}---------------------------${re}"
    echo -e "${green}5.${re} 停止服务"
    echo -e "${green}6.${re} 启动服务"
    echo -e "${red}7.${re} 卸载脚本"
    echo -e "${green}0.${re} 退出"
    echo -e ""
    read -p "请输入选项 [0-7]: " choice

    case "${choice}" in
        1) install_main ;;
        2) show_node_info ;;
        3) refresh_domain ;;
        4) change_cfip ;;
        5) systemctl stop ${service_core} ${service_argo} && echo -e "${red}服务已停止${re}" ;;
        6) systemctl start ${service_core} ${service_argo} && echo -e "${green}服务已启动${re}" ;;
        7) uninstall ;;
        0) exit 0 ;;
        *) echo -e "${red}无效选项${re}" && sleep 1 && menu ;;
    esac
}

# 首次运行创建快捷方式
if [ ! -f /usr/bin/vmess ]; then
    create_shortcut
fi

# 进入菜单
menu
