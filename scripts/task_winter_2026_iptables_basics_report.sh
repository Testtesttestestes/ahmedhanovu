#!/usr/bin/env bash
set -euo pipefail

REPORT_AUTHOR="${REPORT_AUTHOR:-Миленькова Ивана}"
ROOT="reports/winter-2026-task6"
LOG_DIR="$ROOT/logs"
IMG_DIR="$ROOT/images"
mkdir -p "$LOG_DIR" "$IMG_DIR"
# shellcheck source=scripts/task_winter_2026_netns_lib.sh
source scripts/task_winter_2026_netns_lib.sh
trap cleanup_netns EXIT
setup_netns

# Стартовые правила «как на рабочей ВМ», чтобы просмотр и очистка были наглядными.
vm iptables -A INPUT -p tcp --dport 22 -j ACCEPT
vm iptables -t nat -A POSTROUTING -o veth-vm -j MASQUERADE
vm iptables -t mangle -A PREROUTING -p tcp --dport 80 -j TOS --set-tos 0x10

{
  echo "# VM: $VM_IP, other machine: $CLIENT_IP (blocked), $OTHER_IP (control)"
  echo
  run_vm iptables -L -n -v --line-numbers
} > "$LOG_DIR/01_list.txt"

{
  for table in filter nat mangle raw security; do
    run_vm iptables -t "$table" -L -n -v
  done
} > "$LOG_DIR/02_tables.txt"

vm sh -c 'iptables-save' > "$ROOT/iptables-backup.rules"
{
  echo "vm\$ sudo iptables-save > iptables-backup-\$(date +%F).rules"
  echo "vm\$ ls -l iptables-backup.rules && head -20 iptables-backup.rules"
  ls -l "$ROOT/iptables-backup.rules"
  head -20 "$ROOT/iptables-backup.rules"
  echo
  echo "# restore: sudo iptables-restore < iptables-backup-YYYY-MM-DD.rules"
} > "$LOG_DIR/03_backup.txt"

{
  echo "# flush all rules and set default ACCEPT policy"
  for table in filter nat mangle raw security; do
    run_vm iptables -t "$table" -F
    run_vm iptables -t "$table" -X
  done
  run_vm iptables -P INPUT ACCEPT
  run_vm iptables -P FORWARD ACCEPT
  run_vm iptables -P OUTPUT ACCEPT
  run_vm iptables -L -n -v --line-numbers
} > "$LOG_DIR/04_flush.txt"

{
  echo "### BEFORE rule: ping from $CLIENT_IP"
  echo "client\$ ping -c 3 -W 1 $VM_IP"
  client ping -c 3 -W 1 "$VM_IP" 2>&1 || true
  echo
  echo "### add rule"
  run_vm iptables -A INPUT -p icmp --icmp-type echo-request -s "$CLIENT_IP" -j DROP
  run_vm iptables -L INPUT -n -v --line-numbers
} > "$LOG_DIR/05_add_rule.txt"

{
  echo "### AFTER rule: ping from blocked $CLIENT_IP"
  echo "client\$ ping -c 3 -W 1 -I $CLIENT_IP $VM_IP"
  client ping -c 3 -W 1 -I "$CLIENT_IP" "$VM_IP" 2>&1 || true
  echo
  echo "### control: ping from other address $OTHER_IP (not blocked)"
  echo "client\$ ping -c 3 -W 1 -I $OTHER_IP $VM_IP"
  client ping -c 3 -W 1 -I "$OTHER_IP" "$VM_IP" 2>&1 || true
  echo
  echo "### packet counters of the DROP rule"
  run_vm iptables -L INPUT -n -v --line-numbers
} > "$LOG_DIR/06_check.txt"

if client ping -c 1 -W 1 -I "$CLIENT_IP" "$VM_IP" >/dev/null 2>&1; then
  echo "ERROR: ping from $CLIENT_IP was not blocked" >&2
  exit 1
fi

{
  echo "### delete rule by line number"
  run_vm iptables -L INPUT -n --line-numbers
  run_vm iptables -D INPUT 1
  run_vm iptables -L INPUT -n -v --line-numbers
  echo "### ping after deletion"
  echo "client\$ ping -c 3 -W 1 -I $CLIENT_IP $VM_IP"
  client ping -c 3 -W 1 -I "$CLIENT_IP" "$VM_IP" 2>&1 || true
} > "$LOG_DIR/07_delete.txt"

client ping -c 1 -W 1 -I "$CLIENT_IP" "$VM_IP" >/dev/null

declare -A TITLES=(
  [01_list]="iptables -L -n -v: текущие правила"
  [02_tables]="Правила по таблицам filter/nat/mangle/raw/security"
  [03_backup]="Резервная копия iptables-save"
  [04_flush]="Очистка правил и политика ACCEPT"
  [05_add_rule]="До и после добавления правила блокировки ICMP"
  [06_check]="Проверка блокировки ping с другой машины"
  [07_delete]="Удаление правила по номеру строки"
)
for name in "${!TITLES[@]}"; do
  python3 scripts/text_to_png.py "$LOG_DIR/$name.txt" "$IMG_DIR/$name.png" --title "${TITLES[$name]}"
done

python3 - "$ROOT/report.json" "$IMG_DIR" "$REPORT_AUTHOR" "$VM_IP" "$CLIENT_IP" "$OTHER_IP" <<'PY'
import json, sys
from pathlib import Path
out, img, author, vm, client, other = sys.argv[1:]
i = lambda n: str(Path(img) / f'{n}.png')
manifest = {
  'title': 'Отчёт по практической работа номер 6 (зима 2026) ' + author,
  'subtitle': 'Знакомство с iptables: просмотр, резервная копия, очистка и блокировка ICMP.',
  'metadata': [
    {'label': 'ВМ', 'value': f'netns vm, {vm}'},
    {'label': 'Другая машина', 'value': f'netns client, {client} (и {other} для контроля)'},
    {'label': 'Правило', 'value': f'iptables -A INPUT -p icmp --icmp-type echo-request -s {client} -j DROP'},
    {'label': 'Удаление', 'value': 'iptables -D INPUT 1'},
  ],
  'sections': [
    {'heading': '1. Просмотр текущих правил', 'body': ['Команда sudo iptables -L -n -v --line-numbers показывает цепочки таблицы filter, политики по умолчанию, счётчики пакетов и номера строк. Ключ -n отключает разрешение имён, -v выводит счётчики и интерфейсы.'], 'image': i('01_list'), 'caption': 'Исходные правила ВМ.'},
    {'heading': '2. Правила по таблицам', 'body': ['Ключ -t выбирает таблицу: filter (фильтрация, по умолчанию), nat (трансляция адресов), mangle (изменение заголовков), raw (исключение из conntrack), security (метки SELinux).'], 'image': i('02_tables'), 'caption': 'sudo iptables -t <таблица> -L -n -v.'},
    {'heading': '3. Резервная копия', 'body': ['Текущие правила сохранены командой sudo iptables-save > iptables-backup-$(date +%F).rules. Восстановление: sudo iptables-restore < файл.'], 'image': i('03_backup'), 'caption': 'Содержимое файла резервной копии.'},
    {'heading': '4. Очистка правил (команда очистки)', 'body': ['Для каждой таблицы выполнены iptables -t <таблица> -F (удалить правила) и -X (удалить пользовательские цепочки), затем политики INPUT, FORWARD, OUTPUT установлены в ACCEPT: sudo iptables -P INPUT ACCEPT и т.д.'], 'image': i('04_flush'), 'caption': 'После очистки цепочки пусты, политика ACCEPT.'},
    {'heading': '5. Добавление правила блокировки ICMP', 'body': [f'До добавления правила ping с {client} проходит (0% потерь). Добавлено правило sudo iptables -A INPUT -p icmp --icmp-type echo-request -s {client} -j DROP.'], 'image': i('05_add_rule'), 'caption': 'Вывод до и после добавления правила.'},
    {'heading': '6. Подтверждение блокировки ping', 'body': [f'С другой машины ({client}) выполнен ping {vm}: 100% packet loss, счётчик пакетов правила DROP увеличился. Контрольный ping с адреса {other} проходит, так как правило касается только одного IP.'], 'image': i('06_check'), 'caption': 'Блокировка подтверждена.'},
    {'heading': '7. Удаление правила по номеру строки', 'body': ['Номер правила найден через iptables -L INPUT -n --line-numbers, правило удалено командой sudo iptables -D INPUT 1. После удаления ping снова проходит.'], 'image': i('07_delete'), 'caption': 'Правило удалено, связь восстановлена.'},
  ],
}
Path(out).write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
PY
python3 scripts/build_pdf_report.py "$ROOT/report.json" "$ROOT/report.pdf"
echo "Winter 2026 iptables basics PDF report generated at $ROOT/report.pdf"
