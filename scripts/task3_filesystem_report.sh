#!/usr/bin/env bash
set -euo pipefail

REPORT_AUTHOR="${REPORT_AUTHOR:-Миленькова Ивана}"
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

cat > "$ROOT/report.json" <<EOF
{
  "title": "Отчёт по практической работа номер 3 ${REPORT_AUTHOR}",
  "subtitle": "Создание, форматирование, монтирование и проверка образа файловой системы ext4.",
  "metadata": [
    {"label": "Автор", "value": "${REPORT_AUTHOR}"},
    {"label": "Файловая система", "value": "ext4"},
    {"label": "Размер образа", "value": "64 МБ"}
  ],
  "sections": [
    {
      "heading": "1. Создание файла-образа",
      "body": [
        "Команда dd формирует файл ext4.img фиксированного размера 64 МБ, который далее используется как виртуальный носитель данных."
      ],
      "image": "${IMG_DIR}/01_dd_create.png",
      "caption": "Рисунок 1 — создание файла-образа заданного размера командой dd."
    },
    {
      "heading": "2. Форматирование в ext4",
      "body": [
        "Утилита mkfs.ext4 подготавливает внутри файла полноценную файловую систему ext4, готовую к монтированию."
      ],
      "image": "${IMG_DIR}/02_format_ext4.png",
      "caption": "Рисунок 2 — форматирование созданного образа в файловую систему ext4."
    },
    {
      "heading": "3. Подготовка точки монтирования",
      "body": [
        "Перед подключением образа создаётся каталог /mnt/fs, который будет использоваться как точка монтирования."
      ],
      "image": "${IMG_DIR}/03_prepare_mount.png",
      "caption": "Рисунок 3 — подготовка каталога для монтирования файловой системы."
    },
    {
      "heading": "4. Монтирование образа",
      "body": [
        "Команда mount -o loop подключает образ как обычную файловую систему и делает его содержимое доступным в каталоге /mnt/fs."
      ],
      "image": "${IMG_DIR}/04_mount.png",
      "caption": "Рисунок 4 — подключение ext4-образа через loop-монтирование."
    },
    {
      "heading": "5. Создание тестовых файлов",
      "body": [
        "После монтирования в файловой системе создаются контрольные текстовые файлы, подтверждающие успешную запись данных."
      ],
      "image": "${IMG_DIR}/05_create_files.png",
      "caption": "Рисунок 5 — создание и просмотр тестовых файлов внутри смонтированного образа."
    },
    {
      "heading": "6. Проверка содержимого и заполнения",
      "body": [
        "Команды cat и df -h показывают содержимое созданного файла и текущие параметры использования смонтированной файловой системы."
      ],
      "image": "${IMG_DIR}/06_verify_content.png",
      "caption": "Рисунок 6 — проверка содержимого файла и информации о занятом месте в ext4-образе."
    },
    {
      "heading": "7. Размонтирование",
      "body": [
        "В завершение образ аккуратно отключается от системы, чтобы избежать потери данных и завершить лабораторную работу корректно."
      ],
      "image": "${IMG_DIR}/07_umount.png",
      "caption": "Рисунок 7 — успешное размонтирование файловой системы."
    }
  ]
}
EOF

python3 scripts/build_pdf_report.py "$ROOT/report.json" "$ROOT/report.pdf"

echo "Task 3 PDF report generated at $ROOT/report.pdf"
