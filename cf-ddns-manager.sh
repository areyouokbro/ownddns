#!/usr/bin/env bash

set -e

DDNS_URL="https://raw.githubusercontent.com/aipeach/cloudflare-api-v4-ddns/master/cf-v4-ddns.sh"
DDNS_SCRIPT="/usr/local/bin/cf-ddns.sh"
CRON_FILE="/tmp/cf_ddns_cron"

# ===== 参数 =====
CFKEY=""
CFUSER=""
CFZONE=""
CFHOST=""
CFTYPE="A"

# ===== 解析参数 =====
while getopts k:u:z:h:t: opt; do
  case $opt in
    k) CFKEY="$OPTARG" ;;
    u) CFUSER="$OPTARG" ;;
    z) CFZONE="$OPTARG" ;;
    h) CFHOST="$OPTARG" ;;
    t) CFTYPE="$OPTARG" ;;
    *) echo "Usage: $0 -k APIKEY -u EMAIL -z ZONE -h HOST [-t A|AAAA]"; exit 1 ;;
  esac
done

# ===== 检查参数 =====
if [[ -z "$CFKEY" || -z "$CFUSER" || -z "$CFZONE" || -z "$CFHOST" ]]; then
  echo "[!] 参数不完整"
  echo "Usage: $0 -k APIKEY -u EMAIL -z ZONE -h HOST [-t A|AAAA]"
  exit 1
fi

# ===== 下载脚本 =====
echo "[*] 下载 DDNS 脚本..."
curl -fsSL "$DDNS_URL" -o "$DDNS_SCRIPT"
chmod +x "$DDNS_SCRIPT"

# ===== 写入 wrapper 脚本 =====
WRAPPER="/usr/local/bin/cf-ddns-run.sh"

cat > $WRAPPER <<EOF
#!/usr/bin/env bash
$DDNS_SCRIPT -k "$CFKEY" -u "$CFUSER" -z "$CFZONE" -h "$CFHOST" -t "$CFTYPE"
EOF

chmod +x $WRAPPER

# ===== 写入 cron =====
echo "[*] 安装定时任务..."

crontab -l 2>/dev/null | grep -v "$WRAPPER" > $CRON_FILE || true
echo "*/1 * * * * $WRAPPER >/dev/null 2>&1" >> $CRON_FILE
crontab $CRON_FILE
rm -f $CRON_FILE

echo "[+] 安装完成！"
echo "-----------------------------------"
echo "域名: $CFHOST"
echo "类型: $CFTYPE"
echo "已设置每分钟自动更新"
echo "-----------------------------------"

# ===== 测试运行 =====
echo "[*] 测试运行一次..."
bash $WRAPPER

echo "[✔] 完成"
