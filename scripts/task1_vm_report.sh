#!/usr/bin/env bash
set -euo pipefail

SURNAME="${SURNAME:-Ivanov}"
DISTRO="${DISTRO:-ubuntu-22.04}"
REPORT_AUTHOR="${REPORT_AUTHOR:-Миленькова Ивана}"
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

cat > "$ROOT/report.json" <<EOF
{
  "title": "Отчёт по практической работа номер 1 ${REPORT_AUTHOR}",
  "subtitle": "Подготовка облачного образа Linux и конфигурации виртуальной машины.",
  "metadata": [
    {"label": "Автор", "value": "${REPORT_AUTHOR}"},
    {"label": "Дистрибутив", "value": "${DISTRO}"},
    {"label": "Пользователь cloud-init", "value": "${SURNAME}"}
  ],
  "sections": [
    {
      "heading": "1. Создание виртуального диска",
      "body": [
        "Сценарий создаёт новый диск формата qcow2 объёмом 20 ГБ, который затем будет использоваться для запуска виртуальной машины."
      ],
      "image": "${IMG_DIR}/qemu_img_create.png",
      "caption": "Рисунок 1 — результат выполнения команды qemu-img create для подготовки диска виртуальной машины."
    },
    {
      "heading": "2. Загрузка cloud image Ubuntu",
      "body": [
        "Готовый cloud image скачивается с официального сервера Ubuntu и используется как базовый образ для дальнейшей настройки стенда."
      ],
      "image": "${IMG_DIR}/cloud_image_download.png",
      "caption": "Рисунок 2 — загрузка cloud image Ubuntu для последующего развёртывания."
    },
    {
      "heading": "3. Проверка параметров образа",
      "body": [
        "После скачивания образ проверяется командой qemu-img info, чтобы убедиться в корректном формате и доступности файла."
      ],
      "image": "${IMG_DIR}/qemu_img_info.png",
      "caption": "Рисунок 3 — сведения об облачном образе, полученные через qemu-img info."
    },
    {
      "heading": "4. Подготовка cloud-init",
      "body": [
        "Файлы user-data и meta-data объединяются в seed.iso. В конфигурации заранее создаётся пользователь ${SURNAME} с правами sudo."
      ],
      "image": "${IMG_DIR}/cloud_init_iso.png",
      "caption": "Рисунок 4 — создание seed.iso с параметрами cloud-init и данными пользователя."
    },
    {
      "heading": "5. Команда запуска виртуальной машины",
      "body": [
        "В отчёт включается сформированная команда запуска QEMU, которую можно использовать как основу для старта лабораторной виртуальной машины."
      ],
      "image": "${IMG_DIR}/vm_start_command.png",
      "caption": "Рисунок 5 — итоговая команда запуска виртуальной машины с подключённым диском и seed.iso."
    }
  ]
}
EOF

python3 scripts/build_pdf_report.py "$ROOT/report.json" "$ROOT/report.pdf"

echo "Task 1 PDF report generated at $ROOT/report.pdf"
