#!/usr/bin/env bash

set -e

DDNS_URL="https://raw.githubusercontent.com/aipeach/cloudflare-api-v4-ddns/master/cf-v4-ddns.sh"

DDNS_SCRIPT="/usr/local/bin/cf-ddns.sh"
WRAPPER="/usr/local/bin/cf-ddns-run.sh"
CRON_TMP="/tmp/cf_ddns_cron"

# =========================
# 🔧 自动检测 + 安装 cron
# =========================
check_and_install_cron() {
    echo "[*] 检查 cron 服务..."

    # Debian / Ubuntu
    if command -v apt >/dev/null 2>&1; then
        if ! dpkg -l | grep -q cron; then
            echo "[*] 未检测到 cron，正在安装..."
            apt update -y
            apt install cron -y
        fi

        systemctl enable --now cron || true
        echo "[+] cron 已启用 (Debian/Ubuntu)"

    # Arch Linux
    elif command -v pacman >/dev/null 2>&1; then
        if ! pacman -Qi cronie >/dev/null 2>&1; then
            echo "[*] 未检测到 cronie，正在安装..."
            pacman -Sy --noconfirm cronie
        fi

        systemctl enable --now cronie || true
        echo "[+] cronie 已启用 (Arch)"

    # CentOS / RHEL
    elif command -v yum >/dev/null 2>&1; then
        if ! rpm -qa | grep -q cronie; then
            echo "[*] 未检测到 cronie，正在安装..."
            yum install -y cronie
        fi

        systemctl enable --now crond || true
        echo "[+] cronie 已启用 (CentOS/RHEL)"

    else
        echo "[!] 未知系统，请手动安装 cron"
        exit 1
    fi
}

# =========================
# ❌ 卸载
# =========================
uninstall() {
    echo "[*] Uninstalling..."

    crontab -l 2>/dev/null | grep -v "cf-ddns-run.sh" | crontab - || true

    rm -f "$WRAPPER"
    rm -f "$DDNS_SCRIPT"
    rm -f /usr/local/bin/cf-ddns-manager.sh

    rm -f ~/.cf-wan_ip_* ~/.cf-id_* 2>/dev/null || true

    echo "[+] 完全卸载完成"
    exit 0
}

# =========================
# 📌 uninstall 入口
# =========================
if [[ "$1" == "uninstall" ]]; then
    uninstall
fi

# =========================
# 📥 参数解析
# =========================
CFKEY=""
CFUSER=""
CFZONE=""
CFHOST=""
CFTYPE="A"

while getopts k:u:z:h:t: opt; do
  case $opt in
    k) CFKEY="$OPTARG" ;;
    u) CFUSER="$OPTARG" ;;
    z) CFZONE="$OPTARG" ;;
    h) CFHOST="$OPTARG" ;;
    t) CFTYPE="$OPTARG" ;;
    *) echo "Usage: $0 -k KEY -u EMAIL -z ZONE -h HOST [-t A|AAAA]"; exit 1 ;;
  esac
done

# =========================
# 📌 参数检查
# =========================
if [[ -z "$CFKEY" || -z "$CFUSER" || -z "$CFZONE" || -z "$CFHOST" ]]; then
    echo "[!] 参数不完整"
    exit 1
fi

# =========================
# 🧠 自动安装 cron
# =========================
check_and_install_cron

# =========================
# 📥 下载 DDNS 脚本
# =========================
echo "[*] 下载 DDNS 脚本..."
curl -fsSL "$DDNS_URL" -o "$DDNS_SCRIPT"
chmod +x "$DDNS_SCRIPT"

# =========================
# 🧩 生成运行脚本
# =========================
cat > "$WRAPPER" <<EOF
#!/usr/bin/env bash
/usr/bin/env bash $DDNS_SCRIPT -k "$CFKEY" -u "$CFUSER" -z "$CFZONE" -h "$CFHOST" -t "$CFTYPE"
EOF

chmod +x "$WRAPPER"

# =========================
# ⏰ 写入 cron
# =========================
echo "[*] 写入定时任务..."

crontab -l 2>/dev/null | grep -v "$WRAPPER" > "$CRON_TMP" || true
echo "*/1 * * * * $WRAPPER >/dev/null 2>&1" >> "$CRON_TMP"
crontab "$CRON_TMP"
rm -f "$CRON_TMP"

# =========================
# 🚀 测试运行
# =========================
echo "[*] 测试运行..."
bash "$WRAPPER"

echo ""
echo "[+] 安装完成"
echo "--------------------------------"
echo "域名: $CFHOST"
echo "类型: $CFTYPE"
echo "--------------------------------"
