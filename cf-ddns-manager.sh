#!/usr/bin/env bash

set -e

DDNS_URL="https://raw.githubusercontent.com/areyouokbro/ownddns/main/cf-ddns.sh"

DDNS_SCRIPT="/usr/local/bin/cf-ddns.sh"
WRAPPER="/usr/local/bin/cf-ddns-run.sh"
CRON_TMP="/tmp/cf_ddns_cron"


# =========================
# 自动检测 + 安装 cron
# =========================
check_and_install_cron() {

    echo "[*] 检查 cron 服务..."

    if command -v apt >/dev/null 2>&1; then

        if ! dpkg -l | grep -q cron; then
            echo "[*] 安装 cron..."
            apt update -y
            apt install cron -y
        fi

        systemctl enable --now cron || true
        echo "[+] cron 已启用"

    elif command -v pacman >/dev/null 2>&1; then

        if ! pacman -Qi cronie >/dev/null 2>&1; then
            echo "[*] 安装 cronie..."
            pacman -Sy --noconfirm cronie
        fi

        systemctl enable --now cronie || true
        echo "[+] cronie 已启用"

    elif command -v yum >/dev/null 2>&1; then

        if ! rpm -qa | grep -q cronie; then
            echo "[*] 安装 cronie..."
            yum install -y cronie
        fi

        systemctl enable --now crond || true
        echo "[+] crond 已启用"

    else

        echo "[!] 未知系统，请手动安装 cron"
        exit 1

    fi
}



# =========================
# 卸载
# =========================
uninstall() {

    echo "[*] Uninstalling..."

    crontab -l 2>/dev/null \
    | grep -v "cf-ddns-run.sh" \
    | crontab - || true


    rm -f "$WRAPPER"
    rm -f "$DDNS_SCRIPT"
    rm -f /usr/local/bin/cf-ddns-manager.sh


    rm -f ~/.cf-wan_ip_* ~/.cf-id_* 2>/dev/null || true


    echo "[+] 完全卸载完成"

    exit 0
}



# =========================
# uninstall
# =========================

if [[ "$1" == "uninstall" ]]; then
    uninstall
fi



# =========================
# 参数解析
# =========================

CFKEY=""
CFZONE=""
CFHOST=""
CFTYPE="A"


while getopts k:z:h:t: opt
do

    case $opt in

        k)
            CFKEY="$OPTARG"
            ;;

        z)
            CFZONE="$OPTARG"
            ;;

        h)
            CFHOST="$OPTARG"
            ;;

        t)
            CFTYPE="$OPTARG"
            ;;

        *)

            echo "Usage:"
            echo "$0 -k API_TOKEN -z ZONE -h HOST [-t A|AAAA]"
            exit 1
            ;;

    esac

done



# =========================
# 参数检查
# =========================

if [[ -z "$CFKEY" || -z "$CFZONE" || -z "$CFHOST" ]]; then

    echo "[!] 参数不完整"
    echo ""
    echo "Usage:"
    echo "$0 -k API_TOKEN -z ZONE -h HOST [-t A|AAAA]"
    exit 1

fi



# =========================
# 安装 cron
# =========================

check_and_install_cron



# =========================
# 下载 DDNS
# =========================

echo "[*] 下载 DDNS 脚本..."

curl -fsSL "$DDNS_URL" -o "$DDNS_SCRIPT"

chmod +x "$DDNS_SCRIPT"



# =========================
# 创建运行脚本
# =========================

echo "[*] 创建运行脚本..."

cat > "$WRAPPER" <<EOF
#!/usr/bin/env bash

/usr/bin/env bash "$DDNS_SCRIPT" \\
-k "$CFKEY" \\
-z "$CFZONE" \\
-h "$CFHOST" \\
-t "$CFTYPE"

EOF


chmod +x "$WRAPPER"



# =========================
# 添加 cron
# =========================

echo "[*] 写入定时任务..."

crontab -l 2>/dev/null \
| grep -v "$WRAPPER" > "$CRON_TMP" || true


echo "*/1 * * * * $WRAPPER >/dev/null 2>&1" >> "$CRON_TMP"


crontab "$CRON_TMP"

rm -f "$CRON_TMP"



# =========================
# 测试
# =========================

echo "[*] 测试运行..."

bash "$WRAPPER"



echo ""
echo "[+] 安装完成"
echo "--------------------------------"
echo "域名: $CFHOST"
echo "类型: $CFTYPE"
echo "认证: Cloudflare API Token"
echo "--------------------------------"
