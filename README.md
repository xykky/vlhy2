# Sing-Box Hysteria2 & Reality 快速配置脚本

[![作者](https://img.shields.io/badge/作者-jcnf--那坨-blue.svg)](https://ybfl.net)
[![TG频道](https://img.shields.io/badge/TG频道-@mffjc-宗绿色.svg)](https://t.me/mffjc)
[![TG交流群](https://img.shields.io/badge/TG交流群-点击加入-yellow.svg)](https://t.me/+TDz0jE2WcAvfgmLi)
<!-- 你可以在这里添加更多徽章，例如 License, GitHub stars 等 -->

一个用于在 Linux 服务器上快速安装、配置和管理 [Sing-Box](https://github.com/SagerNet/sing-box) 的 Shell 脚本，特别针对 Hysteria2 和 VLESS Reality 协议进行了优化。

## 特性

*   **一键安装 Sing-Box (beta 版)**：自动从官方渠道下载并安装最新 beta 版本的 Sing-Box。
*   **多种安装模式**：
    *   同时安装 Hysteria2 和 Reality (VLESS) 服务，实现共存。
    *   单独安装 Hysteria2 服务。
    *   单独安装 Reality (VLESS) 服务。
*   **自动化配置**：
    *   Hysteria2: 自动生成自签名证书、随机密码。
    *   Reality (VLESS): 自动生成 UUID、Reality Keypair (私钥和公钥)。
    *   自动填充生成的凭证到 `config.json` 配置文件。
    *   用户可自定义监听端口、伪装域名 (SNI) 等关键参数。
*   **Systemd 服务管理**：
    *   自动创建并配置 Sing-Box 的 systemd 服务。
    *   方便地启动、停止、重启、查看服务状态及日志。
    *   设置开机自启。
*   **导入信息与二维码**：
    *   安装完成后，自动显示详细的客户端导入参数。
    *   如果系统已安装 `qrencode`，则会直接在终端显示导入链接的二维码。
    *   支持随时查看上次成功安装的配置信息及二维码。
*   **依赖自动处理**：
    *   自动检测核心依赖 (`curl`, `openssl`, `jq`) 和可选依赖 (`qrencode`)。
    *   如果依赖缺失，会提示用户并尝试通过系统包管理器 (apt, yum, dnf) 自动安装。
*   **便捷管理**：
    *   提供菜单式交互界面，操作简单直观。
    *   支持查看和编辑 Sing-Box 配置文件 (使用 `nano`)。
    *   一键更新 Sing-Box 内核。
    *   一键卸载 Sing-Box 及相关配置。
*   **信息持久化**：上次成功安装的配置参数会被保存，方便后续通过菜单再次查看。

## 环境要求

*   Linux (x86_64 / amd64, aarch64 / arm64 架构理论上支持，未全面测试)
*   root 权限 (脚本内操作需要 sudo)
*   核心依赖: `curl`, `openssl`, `jq` (脚本会尝试自动安装)
*   可选依赖: `qrencode` (用于显示二维码，脚本会尝试自动安装)

## 使用方法

### 1. 下载脚本

```bash
wget -O sb-manager.sh <你的脚本在GitHub上的Raw链接>
# 例如: wget -O sb-manager.sh https://raw.githubusercontent.com/你的用户名/你的仓库名/main/sb-manager.sh
chmod +x sb-manager.sh
