#!/usr/bin/env bash

set -e

INSTALL_PATH="/usr/local/bin/cf-ddns-manager.sh"
REPO_RAW="https://raw.githubusercontent.com/你的用户名/你的仓库/main/cf-ddns-manager.sh"

echo "[*] Installing cf-ddns-manager..."

# ===== 下载管理脚本 =====
curl -fsSL "$REPO_RAW" -o "$INSTALL_PATH"

# ===== 赋权 =====
chmod +x "$INSTALL_PATH"

echo "[+] Installed to $INSTALL_PATH"

# ===== 判断是否带参数 =====
if [ "$#" -eq 0 ]; then
    echo ""
    echo "Usage:"
    echo "bash <(curl -sL https://raw.githubusercontent.com/你的用户名/你的仓库/main/install.sh) \\"
    echo "  -k APIKEY -u EMAIL -z ZONE -h HOST [-t A|AAAA]"
    exit 0
fi

# ===== 直接执行（带参数安装 + 运行）=====
echo "[*] Running manager..."
"$INSTALL_PATH" "$@"
