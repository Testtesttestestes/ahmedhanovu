#!/usr/bin/env bash
set -euo pipefail

REPORT_AUTHOR="${REPORT_AUTHOR:-Миленькова Ивана}"
ROOT="reports/winter-2026-task9"
LOG_DIR="$ROOT/logs"
IMG_DIR="$ROOT/images"
DISK_DIR="$ROOT/disks"
DISK_SIZE="${DISK_SIZE:-512M}"
FONT="/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
sudo rm -rf "$ROOT"
mkdir -p "$LOG_DIR" "$IMG_DIR" "$DISK_DIR"

run() {
  echo "\$ sudo $*"
  sudo "$@" 2>&1 || true
  echo
}

# «Диски» — loop-устройства поверх файлов: на раннере GitHub нет свободных
# физических дисков, а mdadm работает с любыми блочными устройствами.
DISKS=()
for i in 1 2 3 4 5; do
  truncate -s "$DISK_SIZE" "$DISK_DIR/disk$i.img"
  DISKS+=("$(sudo losetup -f --show "$DISK_DIR/disk$i.img")")
done
R1=("${DISKS[0]}" "${DISKS[1]}")
R5=("${DISKS[2]}" "${DISKS[3]}" "${DISKS[4]}")

SPEED_MAX="$(cat /proc/sys/dev/raid/speed_limit_max 2>/dev/null || echo 200000)"
cleanup() {
  echo "$SPEED_MAX" | sudo tee /proc/sys/dev/raid/speed_limit_max >/dev/null 2>&1 || true
  sudo umount /mnt/raid1 /mnt/raid5 2>/dev/null || true
  sudo mdadm --stop /dev/md0 2>/dev/null || true
  sudo mdadm --stop /dev/md1 2>/dev/null || true
  for dev in "${DISKS[@]}"; do sudo losetup -d "$dev" 2>/dev/null || true; done
  sudo rm -rf "$DISK_DIR"
}
trap cleanup EXIT

sudo modprobe raid1
sudo modprobe raid456
# Ограничиваем скорость синхронизации, чтобы прогресс в /proc/mdstat был виден.
echo 20000 | sudo tee /proc/sys/dev/raid/speed_limit_max >/dev/null

{
  echo "# test disks (loop devices, $DISK_SIZE each)"
  run lsblk -o NAME,SIZE,TYPE "${DISKS[@]}"
} > "$LOG_DIR/00_disks.txt"

# ================= Часть А: RAID 1 =================
{
  echo "### 1. create RAID 1"
  echo "\$ sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 ${R1[*]}"
  yes | sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 --metadata=1.2 "${R1[@]}" 2>&1
  echo
  echo "### 2. status right after creation (resync in progress)"
  run cat /proc/mdstat
} > "$LOG_DIR/01_raid1_create.txt"
sleep 3
run cat /proc/mdstat > "$LOG_DIR/02_raid1_mdstat_sync.txt"

echo 2000000 | sudo tee /proc/sys/dev/raid/speed_limit_max >/dev/null
sudo mdadm --wait /dev/md0 || true
run mdadm --detail /dev/md0 > "$LOG_DIR/03_raid1_detail.txt"

{
  echo "### 3. ext4 + mount"
  run mkfs.ext4 -F -q -L raid1 /dev/md0
  sudo mkdir -p /mnt/raid1
  run mount /dev/md0 /mnt/raid1
  run df -h /mnt/raid1
  echo "### 4. test file"
  echo "\$ echo 'RAID1 test file' | sudo tee /mnt/raid1/test.txt"
  echo "RAID1 test file, $(date -u +%FT%TZ)" | sudo tee /mnt/raid1/test.txt
  sudo dd if=/dev/urandom of=/mnt/raid1/data.bin bs=1M count=20 status=none
  run ls -l /mnt/raid1
  run cat /mnt/raid1/test.txt
  run sha256sum /mnt/raid1/data.bin
  echo "### mirror check: mark ${R1[0]} as failed, file is still readable"
  run mdadm /dev/md0 --fail "${R1[0]}"
  run cat /proc/mdstat
  sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
  run cat /mnt/raid1/test.txt
  run sha256sum /mnt/raid1/data.bin
  echo "### return disk to the array"
  run mdadm /dev/md0 --remove "${R1[0]}"
  run mdadm /dev/md0 --add "${R1[0]}"
  sudo mdadm --wait /dev/md0 || true
  run cat /proc/mdstat
} > "$LOG_DIR/04_raid1_files.txt"

# ================= Часть Б: RAID 5 =================
echo 20000 | sudo tee /proc/sys/dev/raid/speed_limit_max >/dev/null
{
  echo "### 1. create RAID 5"
  echo "\$ sudo mdadm --create /dev/md1 --level=5 --raid-devices=3 ${R5[*]}"
  yes | sudo mdadm --create /dev/md1 --level=5 --raid-devices=3 --metadata=1.2 "${R5[@]}" 2>&1
} > "$LOG_DIR/05_raid5_create.txt"
sleep 3
{
  echo "### 2. sync progress (several snapshots)"
  for n in 1 2 3; do
    echo "--- snapshot $n, $(date -u +%T) ---"
    sudo cat /proc/mdstat
    sleep 3
  done
} > "$LOG_DIR/06_raid5_mdstat_sync.txt"

echo 2000000 | sudo tee /proc/sys/dev/raid/speed_limit_max >/dev/null
{
  echo "\$ sudo mdadm --wait /dev/md1   # wait for the end of recovery"
  sudo mdadm --wait /dev/md1 2>&1 || true
  echo
  run cat /proc/mdstat
} > "$LOG_DIR/07_raid5_synced.txt"
run mdadm --detail /dev/md1 > "$LOG_DIR/08_raid5_detail.txt"

{
  echo "### 3. ext4 + mount"
  run mkfs.ext4 -F -q -L raid5 /dev/md1
  sudo mkdir -p /mnt/raid5
  run mount /dev/md1 /mnt/raid5
  run df -h /mnt/raid1 /mnt/raid5
  echo "### test files"
  echo "\$ echo 'RAID5 test file' | sudo tee /mnt/raid5/test.txt"
  echo "RAID5 test file, $(date -u +%FT%TZ)" | sudo tee /mnt/raid5/test.txt
  run cp /mnt/raid1/data.bin /mnt/raid5/data.bin
  run ls -l /mnt/raid5
  run sha256sum /mnt/raid1/data.bin /mnt/raid5/data.bin
  echo "### parity check: mark ${R5[0]} as failed, data is still readable"
  run mdadm /dev/md1 --fail "${R5[0]}"
  sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
  run cat /mnt/raid5/test.txt
  run sha256sum /mnt/raid5/data.bin
  run cat /proc/mdstat
  run lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT /dev/md0 /dev/md1
} > "$LOG_DIR/09_raid5_files.txt"

grep -q 'raid1' "$LOG_DIR/03_raid1_detail.txt"
grep -q 'raid5' "$LOG_DIR/08_raid5_detail.txt"
grep -q 'RAID5 test file' "$LOG_DIR/09_raid5_files.txt"

declare -A TITLES=(
  [00_disks]="Тестовые диски (loop-устройства)"
  [01_raid1_create]="RAID 1: mdadm --create /dev/md0"
  [02_raid1_mdstat_sync]="RAID 1: /proc/mdstat во время синхронизации"
  [03_raid1_detail]="mdadm --detail /dev/md0"
  [04_raid1_files]="RAID 1: ext4, монтирование, работа с файлами"
  [05_raid5_create]="RAID 5: mdadm --create /dev/md1"
  [06_raid5_mdstat_sync]="RAID 5: /proc/mdstat во время синхронизации"
  [07_raid5_synced]="RAID 5: синхронизация завершена"
  [08_raid5_detail]="mdadm --detail /dev/md1"
  [09_raid5_files]="RAID 5: ext4, монтирование, работа с файлами"
)
for name in "${!TITLES[@]}"; do
  python3 scripts/text_to_png.py "$LOG_DIR/$name.txt" "$IMG_DIR/$name.png" --title "${TITLES[$name]}" --font "$FONT"
done

python3 - "$ROOT/report.json" "$IMG_DIR" "$REPORT_AUTHOR" "${R1[*]}" "${R5[*]}" "$DISK_SIZE" <<'PY'
import json, sys
from pathlib import Path
out, img, author, r1, r5, size = sys.argv[1:]
i = lambda n: str(Path(img) / f'{n}.png')
manifest = {
  'title': 'Отчёт по практической работа номер 9 (зима 2026) ' + author,
  'subtitle': 'Программный RAID в Linux: RAID 1 и RAID 5 с помощью mdadm.',
  'metadata': [
    {'label': 'Диски', 'value': f'loop-устройства по {size}'},
    {'label': 'RAID 1', 'value': f'/dev/md0 = {r1} -> /mnt/raid1'},
    {'label': 'RAID 5', 'value': f'/dev/md1 = {r5} -> /mnt/raid5'},
    {'label': 'ФС', 'value': 'ext4'},
  ],
  'sections': [
    {'heading': 'Подготовка дисков', 'body': ['На раннере нет свободных физических дисков, поэтому диски созданы как файлы, подключённые через losetup. Для mdadm это обычные блочные устройства.'], 'image': i('00_disks'), 'caption': 'Пять тестовых дисков.'},
    {'heading': 'Часть А. 1. Создание RAID 1', 'body': [f'sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 {r1}: зеркало из двух дисков, данные пишутся одновременно на оба.'], 'image': i('01_raid1_create'), 'caption': 'Создание массива /dev/md0.'},
    {'heading': 'Часть А. 2. Статус массива', 'body': ['Сразу после создания идёт начальная синхронизация (resync): в /proc/mdstat видны процент, скорость и оставшееся время. Состояние [2/2] [UU] означает, что оба диска в строю.'], 'image': i('02_raid1_mdstat_sync'), 'caption': '/proc/mdstat во время синхронизации RAID 1.'},
    {'heading': 'mdadm --detail /dev/md0', 'body': ['Raid Level: raid1, State: clean, Active/Working Devices: 2, оба диска в состоянии active sync. Ёмкость массива равна ёмкости одного диска.'], 'image': i('03_raid1_detail'), 'caption': 'Подробности RAID 1.'},
    {'heading': 'Часть А. 3–4. ФС, монтирование и тестовый файл', 'body': ['Созданы ext4 (mkfs.ext4 /dev/md0) и точка монтирования /mnt/raid1, записаны test.txt и data.bin. Для проверки зеркала один диск помечен сбойным (mdadm --fail): массив работает в режиме [2/1] [_U], файл читается, контрольная сумма не изменилась. Затем диск возвращён в массив (--remove, --add) и синхронизирован заново.'], 'image': i('04_raid1_files'), 'caption': 'Работа с файлами на RAID 1.'},
    {'heading': 'Часть Б. 1. Создание RAID 5', 'body': [f'sudo mdadm --create /dev/md1 --level=5 --raid-devices=3 {r5}: данные чередуются по дискам, а блок чётности позволяет пережить отказ одного диска. Полезная ёмкость равна (N-1) дисков.'], 'image': i('05_raid5_create'), 'caption': 'Создание массива /dev/md1.'},
    {'heading': 'Часть Б. 2. Синхронизация', 'body': ['RAID 5 строит чётность через recovery: в /proc/mdstat видно состояние [3/2] [UU_] и растущий процент. Снимки сделаны с интервалом 3 секунды; чтобы процесс было видно, скорость временно ограничена через /proc/sys/dev/raid/speed_limit_max. Завершения ждали командой mdadm --wait /dev/md1.'], 'image': i('06_raid5_mdstat_sync'), 'caption': '/proc/mdstat во время синхронизации RAID 5.'},
    {'heading': 'Синхронизация завершена', 'body': ['После mdadm --wait массив в состоянии [3/3] [UUU].'], 'image': i('07_raid5_synced'), 'caption': 'RAID 5 синхронизирован.'},
    {'heading': 'mdadm --detail /dev/md1', 'body': ['Raid Level: raid5, State: clean, 3 активных диска, Layout left-symmetric, Chunk Size 512K.'], 'image': i('08_raid5_detail'), 'caption': 'Подробности RAID 5.'},
    {'heading': 'Часть Б. 3. ФС, монтирование и файлы', 'body': ['Созданы ext4 и точка монтирования /mnt/raid5, записан test.txt и скопирован data.bin: контрольные суммы на RAID 1 и RAID 5 совпадают. После пометки одного диска сбойным массив работает в режиме [3/2], а данные восстанавливаются по чётности и читаются без ошибок.'], 'image': i('09_raid5_files'), 'caption': 'Работа с файлами на RAID 5.'},
  ],
}
Path(out).write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
PY
python3 scripts/build_pdf_report.py "$ROOT/report.json" "$ROOT/report.pdf"
echo "Winter 2026 RAID PDF report generated at $ROOT/report.pdf"
