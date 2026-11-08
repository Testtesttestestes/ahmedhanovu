#!/usr/bin/env bash
set -euo pipefail

REPORT_AUTHOR="${REPORT_AUTHOR:-Миленькова Ивана}"
ROOT="reports/winter-2026-task7"
LOG_DIR="$ROOT/logs"
IMG_DIR="$ROOT/images"
SRV_DIR="$ROOT/server"
rm -rf "$ROOT"
mkdir -p "$LOG_DIR" "$IMG_DIR" "$SRV_DIR/www"
# shellcheck source=scripts/task_winter_2026_netns_lib.sh
source scripts/task_winter_2026_netns_lib.sh

trap cleanup_netns EXIT
setup_netns

# LOG из сетевого пространства имён попадает в dmesg только при этом sysctl.
sudo sysctl -q -w net.netfilter.nf_log_all_netns=1

# --- Сервисы ВМ: SSH (22), HTTP (80), HTTPS (443), а также «лишний» сервис на 3306.
ssh-keygen -q -t ed25519 -N '' -f "$SRV_DIR/ssh_host_ed25519_key" <<<y >/dev/null
sudo mkdir -p /run/sshd
vm /usr/sbin/sshd -D -f /dev/null -p 22 -o ListenAddress="$VM_IP" \
  -o HostKey="$(pwd)/$SRV_DIR/ssh_host_ed25519_key" -o PidFile=none >/dev/null 2>&1 &
echo '<h1>Winter 2026 firewall test page</h1>' > "$SRV_DIR/www/index.html"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj "/CN=$VM_IP" \
  -keyout "$SRV_DIR/key.pem" -out "$SRV_DIR/cert.pem" >/dev/null 2>&1
vm python3 -m http.server 80 --bind "$VM_IP" --directory "$SRV_DIR/www" >/dev/null 2>&1 &
vm python3 - "$VM_IP" "$SRV_DIR" >/dev/null 2>&1 <<'PY' &
import functools, http.server, ssl, sys
ip, d = sys.argv[1], sys.argv[2]
h = functools.partial(http.server.SimpleHTTPRequestHandler, directory=d + '/www')
srv = http.server.HTTPServer((ip, 443), h)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(d + '/cert.pem', d + '/key.pem')
srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
srv.serve_forever()
PY
vm python3 -c "import socket,time;s=socket.socket();s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);s.bind(('$VM_IP',3306));s.listen();time.sleep(600)" >/dev/null 2>&1 &
sleep 2

# --- Построение файервола: каждая команда записывается в журнал.
{
  echo "# 1. default policy DROP for incoming traffic"
  run_vm iptables -P INPUT DROP
  run_vm iptables -P FORWARD DROP
  run_vm iptables -P OUTPUT ACCEPT
  echo "# 2. allow loopback"
  run_vm iptables -A INPUT -i lo -j ACCEPT
  echo "# 3. stateful: allow established and related"
  run_vm iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  run_vm iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
  echo "# 4. allow SSH"
  run_vm iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT
  echo "# 5. allow HTTP/HTTPS"
  run_vm iptables -A INPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW -j ACCEPT
  echo "# 6. allow ICMP echo-request with rate limit"
  run_vm iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/second --limit-burst 4 -j ACCEPT
  echo "# 7. log packets that will be dropped by policy"
  run_vm iptables -A INPUT -m limit --limit 5/min --limit-burst 20 -j LOG --log-prefix "IPTABLES-DROP: " --log-level 4
} > "$LOG_DIR/01_commands.txt"

vm iptables-save > "$ROOT/rules.v4"
{
  echo "# 8. save rules"
  echo "vm\$ sudo iptables-save | sudo tee /etc/iptables/rules.v4"
  echo "vm\$ sudo netfilter-persistent save   # package iptables-persistent"
  echo
  cat "$ROOT/rules.v4"
} > "$LOG_DIR/02_save.txt"

# --- Проверки с «другой машины».
{
  echo "### SSH (22) from $CLIENT_IP"
  echo "client\$ ssh-keyscan -T 3 -t ed25519 $VM_IP"
  client ssh-keyscan -T 3 -t ed25519 "$VM_IP" 2>&1 | grep -v '^#' || true
  echo "client\$ nc -vz -w 3 $VM_IP 22"
  client nc -vz -w 3 "$VM_IP" 22 2>&1 || true
  echo
  echo "### HTTP (80)"
  echo "client\$ curl -sS -m 5 -o /dev/null -w '%{http_code}\n' http://$VM_IP/"
  client curl -sS -m 5 -o /dev/null -w '%{http_code}\n' "http://$VM_IP/" 2>&1 || true
  echo "client\$ curl -s http://$VM_IP/"
  client curl -s -m 5 "http://$VM_IP/" 2>&1 || true
  echo
  echo "### HTTPS (443)"
  echo "client\$ curl -k -sS -m 5 -o /dev/null -w '%{http_code}\n' https://$VM_IP/"
  client curl -k -sS -m 5 -o /dev/null -w '%{http_code}\n' "https://$VM_IP/" 2>&1 || true
  echo
  echo "### closed port 3306 (service listens, but firewall drops)"
  echo "client\$ nc -vz -w 3 $VM_IP 3306"
  client nc -vz -w 3 "$VM_IP" 3306 2>&1 || echo "nc: connection timed out (dropped)"
  echo
  echo "### ICMP with limit (1/s, burst 4): 15 separate pings started in a row"
  echo "# each ping process uses a new ICMP id -> conntrack state NEW -> limit rule"
  echo "client\$ for i in \$(seq 15); do ping -c 1 -W 1 $VM_IP & sleep 0.05; done"
  ping_pids=()
  for _ in $(seq 15); do
    (client ping -c 1 -W 1 "$VM_IP" >/dev/null 2>&1 && echo ok || echo lost) >> "$SRV_DIR/icmp.txt" &
    ping_pids+=($!)
    sleep 0.05
  done
  wait "${ping_pids[@]}"
  echo "replies: $(grep -c '^ok' "$SRV_DIR/icmp.txt" || true) of 15, lost: $(grep -c '^lost' "$SRV_DIR/icmp.txt" || true)"
} > "$LOG_DIR/03_checks.txt"

client nc -z -w 3 "$VM_IP" 22
test "$(client curl -sS -m 5 -o /dev/null -w '%{http_code}' "http://$VM_IP/")" = 200
test "$(client curl -k -sS -m 5 -o /dev/null -w '%{http_code}' "https://$VM_IP/")" = 200
if client nc -z -w 3 "$VM_IP" 3306; then
  echo "ERROR: port 3306 is reachable, firewall is not working" >&2
  exit 1
fi

run_vm iptables -L -n -v --line-numbers > "$LOG_DIR/04_list.txt"

{
  echo "\$ sudo dmesg | grep IPTABLES-DROP"
  sudo dmesg | grep IPTABLES-DROP | tail -15 || echo "(no records)"
} > "$LOG_DIR/05_dmesg.txt"
grep -q 'IPTABLES-DROP' "$LOG_DIR/05_dmesg.txt"

declare -A TITLES=(
  [01_commands]="Последовательность команд файервола"
  [02_save]="Сохранение правил (iptables-save)"
  [03_checks]="Проверка SSH, HTTP/HTTPS, закрытого порта и ICMP"
  [04_list]="sudo iptables -L -n -v"
  [05_dmesg]="sudo dmesg | grep IPTABLES-DROP"
)
for name in "${!TITLES[@]}"; do
  python3 scripts/text_to_png.py "$LOG_DIR/$name.txt" "$IMG_DIR/$name.png" --title "${TITLES[$name]}"
done

python3 - "$ROOT/report.json" "$IMG_DIR" "$REPORT_AUTHOR" "$VM_IP" "$CLIENT_IP" <<'PY'
import json, sys
from pathlib import Path
out, img, author, vm, client = sys.argv[1:]
i = lambda n: str(Path(img) / f'{n}.png')
manifest = {
  'title': 'Отчёт по практической работа номер 7 (зима 2026) ' + author,
  'subtitle': 'Построение базового stateful-файервола на iptables.',
  'metadata': [
    {'label': 'ВМ', 'value': f'netns vm, {vm} (sshd :22, HTTP :80, HTTPS :443, тест :3306)'},
    {'label': 'Клиент', 'value': f'netns client, {client}'},
    {'label': 'Политика INPUT', 'value': 'DROP'},
    {'label': 'Открыто', 'value': 'lo, ESTABLISHED/RELATED, 22, 80, 443, ICMP 1/s'},
  ],
  'sections': [
    {'heading': '1. Последовательность команд', 'body': [
      'Политика INPUT установлена в DROP (iptables -P INPUT DROP). Разрешён loopback (-i lo), без которого перестают работать локальные службы.',
      'Правило conntrack --ctstate ESTABLISHED,RELATED пропускает ответы на уже установленные соединения, INVALID-пакеты отбрасываются.',
      'Новые соединения разрешены на порт 22 (SSH) и 80/443 (multiport). ICMP echo-request ограничен модулем limit: 1 пакет в секунду, всплеск до 4.',
      'Последнее правило LOG с префиксом "IPTABLES-DROP: " пишет в журнал ядра пакеты, которые затем отбросит политика DROP (не более 5 записей в минуту).'],
     'image': i('01_commands'), 'caption': 'Команды построения файервола.'},
    {'heading': '2. Сохранение правил', 'body': ['Правила сохранены командой sudo iptables-save | sudo tee /etc/iptables/rules.v4; с пакетом iptables-persistent они загружаются при старте системы (sudo netfilter-persistent save).'], 'image': i('02_save'), 'caption': 'Содержимое rules.v4.'},
    {'heading': '3. Вывод iptables -L -n -v', 'body': ['Счётчики pkts/bytes показывают, какие правила сработали во время проверок: пакеты SSH, HTTP, HTTPS и ICMP приняты, остальные залогированы и отброшены политикой.'], 'image': i('04_list'), 'caption': 'Итоговые правила с счётчиками.'},
    {'heading': '4. Проверка доступности SSH и веб-сервера', 'body': [f'С клиента {client}: ssh-keyscan и nc получают SSH-баннер на порту 22, curl возвращает код 200 по HTTP и HTTPS. Порт 3306 слушается службой, но соединение завершается тайм-аутом, так как трафик отбрасывается. Из 15 ping, запущенных подряд, ответ получают только первые несколько (burst 4 и 1 пакет/с), остальные отбрасываются: так работает ограничение limit. Отдельные процессы ping нужны потому, что ответы одного процесса conntrack считает ESTABLISHED.'], 'image': i('03_checks'), 'caption': 'Проверки с другой машины.'},
    {'heading': '5. Проверка логов', 'body': ['Команда sudo dmesg | grep IPTABLES-DROP показывает отброшенные пакеты: адрес источника, порт назначения (DPT=3306) и лишние ICMP-запросы сверх лимита.'], 'image': i('05_dmesg'), 'caption': 'Записи IPTABLES-DROP в журнале ядра.'},
  ],
}
Path(out).write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
PY
python3 scripts/build_pdf_report.py "$ROOT/report.json" "$ROOT/report.pdf"
echo "Winter 2026 firewall PDF report generated at $ROOT/report.pdf"
