#!/usr/bin/env bash
set -euo pipefail

SURNAME="${SURNAME:-Ivanov}"
DISTRO="${DISTRO:-ubuntu-22.04}"
ROOT="reports/task1"
LOG_DIR="$ROOT/logs"
IMG_DIR="$ROOT/images"
mkdir -p "$LOG_DIR" "$IMG_DIR"

log_cmd() {
  local name="$1"; shift
  {
    echo "$ $*"
    "$@"
  } >"$LOG_DIR/${name}.txt" 2>&1 || true
  python3 scripts/text_to_png.py "$LOG_DIR/${name}.txt" "$IMG_DIR/${name}.png" --title "$name"
}

cat > "$ROOT/user-data" <<EOF
#cloud-config
users:
  - default
  - name: ${SURNAME}
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
ssh_pwauth: false
EOF

cat > "$ROOT/meta-data" <<EOF
instance-id: vm-lab-01
local-hostname: vm-lab
EOF

log_cmd qemu_img_create qemu-img create -f qcow2 "$ROOT/${DISTRO}.qcow2" 20G
log_cmd cloud_image_download curl -L -o "$ROOT/${DISTRO}-cloudimg.img" "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
log_cmd qemu_img_info qemu-img info "$ROOT/${DISTRO}-cloudimg.img"
log_cmd cloud_init_iso cloud-localds "$ROOT/seed.iso" "$ROOT/user-data" "$ROOT/meta-data"
log_cmd vm_start_command bash -lc "echo qemu-system-x86_64 -m 2048 -smp 2 -drive file=$ROOT/${DISTRO}.qcow2,if=virtio -drive file=$ROOT/seed.iso,format=raw -nographic"

cat > "$ROOT/report.md" <<EOF
# Отчёт по заданию 1

- Дистрибутив: ${DISTRO}
- Имя пользователя в cloud-init: **${SURNAME}**

## 1) Создание диска ВМ
![qemu-img create](images/qemu_img_create.png)

## 2) Загрузка cloud image Linux
![download image](images/cloud_image_download.png)

## 3) Проверка образа
![qemu-img info](images/qemu_img_info.png)

## 4) Подготовка cloud-init c пользователем ${SURNAME}
![cloud-init iso](images/cloud_init_iso.png)

## 5) Команда запуска виртуальной машины
![qemu start command](images/vm_start_command.png)

EOF

echo "Task 1 report generated at $ROOT/report.md"
