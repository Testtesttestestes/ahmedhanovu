#!/usr/bin/env bash
set -euo pipefail

ROOT="reports/task3"
LOG_DIR="$ROOT/logs"
IMG_DIR="$ROOT/images"
MNT_DIR="/mnt/fs"
IMG="$ROOT/ext4.img"
mkdir -p "$LOG_DIR" "$IMG_DIR" "$ROOT"

cleanup() {
  if mountpoint -q "$MNT_DIR"; then
    sudo umount "$MNT_DIR" || true
  fi
}
trap cleanup EXIT

run_capture() {
  local key="$1"; shift
  {
    echo "$ $*"
    bash -lc "$*"
  } >"$LOG_DIR/${key}.txt" 2>&1 || true
  python3 scripts/text_to_png.py "$LOG_DIR/${key}.txt" "$IMG_DIR/${key}.png" --title "$key"
}

run_capture 01_dd_create "dd if=/dev/zero of='$IMG' bs=1M count=64 status=progress"
run_capture 02_format_ext4 "mkfs.ext4 -F '$IMG'"
run_capture 03_prepare_mount "sudo mkdir -p '$MNT_DIR' && ls -ld '$MNT_DIR'"
run_capture 04_mount "sudo mount -o loop '$IMG' '$MNT_DIR' && mount | grep '$MNT_DIR'"
run_capture 05_create_files "echo 'File system lab data' | sudo tee '$MNT_DIR/info.txt' >/dev/null && echo 'Second file' | sudo tee '$MNT_DIR/notes.txt' >/dev/null && sudo ls -la '$MNT_DIR'"
run_capture 06_verify_content "sudo cat '$MNT_DIR/info.txt' && sudo df -h '$MNT_DIR'"
run_capture 07_umount "sudo umount '$MNT_DIR' && echo 'Unmount completed'"

cat > "$ROOT/report.md" <<EOF
# Отчёт по заданию 3 — создание и монтирование образа ФС

## 1) Создание файла-образа командой dd
![dd create](images/01_dd_create.png)

## 2) Форматирование образа в ext4
![mkfs ext4](images/02_format_ext4.png)

## 3) Подготовка каталога /mnt/fs
![prepare mountpoint](images/03_prepare_mount.png)

## 4) Монтирование образа
![mount loop](images/04_mount.png)

## 5) Создание файлов в /mnt/fs
![create files](images/05_create_files.png)

## 6) Проверка содержимого и использования ФС
![verify content](images/06_verify_content.png)

## 7) Размонтирование
![umount](images/07_umount.png)

EOF

echo "Task 3 report generated at $ROOT/report.md"
