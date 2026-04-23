#!/usr/bin/env bash

set -e

INSTALL_PATH="/usr/local/bin/cf-ddns-manager.sh"
REPO_RAW="https://raw.githubusercontent.com/areyouokbro/ownddns/main/cf-ddns-manager.sh"

# ===== root 检查 =====
if [ "$EUID" -ne 0 ]; then
  echo "[!] 请使用 root 运行"
  exit 1
fi

echo "[*] Installing cf-ddns-manager..."

# ===== 下载 =====
if ! curl -fsSL "$REPO_RAW" -o "$INSTALL_PATH"; then
    echo "[!] 下载失败"
    exit 1
fi

chmod +x "$INSTALL_PATH"

echo "[+] Installed to $INSTALL_PATH"

# ===== 没参数就提示 =====
if [ "$#" -eq 0 ]; then
    echo ""
    echo "Usage:"
    echo "bash <(curl -sL https://raw.githubusercontent.com/你的用户名/你的仓库/main/install.sh) \\"
    echo "  -k APIKEY -u EMAIL -z ZONE -h HOST [-t A|AAAA]"
    exit 0
fi

# ===== 直接执行 =====
echo "[*] Running manager..."
"$INSTALL_PATH" "$@"
