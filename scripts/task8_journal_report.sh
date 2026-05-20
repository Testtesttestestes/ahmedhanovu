#!/usr/bin/env bash
set -euo pipefail
REPORT_AUTHOR="${REPORT_AUTHOR:-Миленькова Ивана}"
ROOT="reports/task8"; LOG_DIR="$ROOT/logs"; IMG_DIR="$ROOT/images"
mkdir -p "$LOG_DIR" "$IMG_DIR"
run_capture(){ local k="$1"; shift; { echo "$ $*"; bash -lc "$*"; } >"$LOG_DIR/$k.txt" 2>&1 || true; python3 scripts/text_to_png.py "$LOG_DIR/$k.txt" "$IMG_DIR/$k.png" --title "$k"; }
run_capture 01_last20 "journalctl -n 20 --no-pager"
run_capture 02_ssh "journalctl -u ssh -u sshd --no-pager | tail -n 50"
run_capture 03_enable_ssh "sudo systemctl enable ssh || sudo systemctl enable sshd; sudo systemctl restart ssh || sudo systemctl restart sshd; systemctl is-enabled ssh || systemctl is-enabled sshd"
run_capture 04_hour "journalctl --since '1 hour ago' --no-pager | tail -n 80"
run_capture 05_boot_file "journalctl -b --no-pager > '$ROOT/last_boot.log' && wc -l '$ROOT/last_boot.log' && tail -n 20 '$ROOT/last_boot.log'"
run_capture 06_errors "grep -i 'error' '$ROOT/last_boot.log' | tail -n 50 || true"
cat > "$ROOT/report.json" <<EOF_JSON
{"title":"Отчёт по практической работа номер 8 ${REPORT_AUTHOR}","sections":[{"heading":"8.1 Последние 20 строк","image":"$IMG_DIR/01_last20.png"},{"heading":"8.2 Логи ssh","image":"$IMG_DIR/02_ssh.png"},{"heading":"8.2 enable/restart ssh","image":"$IMG_DIR/03_enable_ssh.png"},{"heading":"8.3 Последний час","image":"$IMG_DIR/04_hour.png"},{"heading":"8.3.1 Лог последней загрузки","image":"$IMG_DIR/05_boot_file.png"},{"heading":"8.3.2 error","image":"$IMG_DIR/06_errors.png"}]}
EOF_JSON
python3 scripts/build_pdf_report.py "$ROOT/report.json" "$ROOT/report.pdf"
