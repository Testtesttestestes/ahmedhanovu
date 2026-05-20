#!/usr/bin/env bash
set -euo pipefail
REPORT_AUTHOR="${REPORT_AUTHOR:-Миленькова Ивана}"
ROOT="reports/task7"; LOG_DIR="$ROOT/logs"; IMG_DIR="$ROOT/images"
mkdir -p "$LOG_DIR" "$IMG_DIR"
run_capture(){ local k="$1"; shift; { echo "$ $*"; bash -lc "$*"; } >"$LOG_DIR/$k.txt" 2>&1 || true; python3 scripts/text_to_png.py "$LOG_DIR/$k.txt" "$IMG_DIR/$k.png" --title "$k"; }
run_capture 01_start "nohup bash -lc 'while :; do :; done' >/tmp/cpu_stress.log 2>&1 & echo \$! > /tmp/stress.pid; cat /tmp/stress.pid"
run_capture 02_find_pid "ps -eo pid,ppid,user,cmd | grep -E 'while :; do :; done|cpu_stress' | grep -v grep"
run_capture 03_top "PID=\$(cat /tmp/stress.pid); top -b -n 1 -p \"\$PID\""
run_capture 04_ps_before "ps -fp \"\$(cat /tmp/stress.pid)\""
run_capture 05_term_kill "PID=\$(cat /tmp/stress.pid); kill -TERM \"\$PID\"; sleep 1; ps -p \"\$PID\" || true; if ps -p \"\$PID\" >/dev/null; then kill -KILL \"\$PID\"; fi"
run_capture 06_ps_after "ps -p \"\$(cat /tmp/stress.pid)\" || true"
cat > "$ROOT/report.json" <<EOF_JSON
{"title":"Отчёт по практической работа номер 7 ${REPORT_AUTHOR}","sections":[{"heading":"7.1 Запуск нагрузки","image":"$IMG_DIR/01_start.png"},{"heading":"7.2 PID","image":"$IMG_DIR/02_find_pid.png"},{"heading":"7.3 top/ресурсы","image":"$IMG_DIR/03_top.png"},{"heading":"7.4 SIGTERM/SIGKILL","image":"$IMG_DIR/05_term_kill.png"},{"heading":"ps до","image":"$IMG_DIR/04_ps_before.png"},{"heading":"ps после","image":"$IMG_DIR/06_ps_after.png"}]}
EOF_JSON
python3 scripts/build_pdf_report.py "$ROOT/report.json" "$ROOT/report.pdf"
