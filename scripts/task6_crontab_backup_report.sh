#!/usr/bin/env bash
set -euo pipefail
REPORT_AUTHOR="${REPORT_AUTHOR:-Миленькова Ивана}"
ROOT="reports/task6"; LOG_DIR="$ROOT/logs"; IMG_DIR="$ROOT/images"
mkdir -p "$LOG_DIR" "$IMG_DIR"
run_capture(){ local k="$1"; shift; { echo "$ $*"; bash -lc "$*"; } >"$LOG_DIR/$k.txt" 2>&1 || true; python3 scripts/text_to_png.py "$LOG_DIR/$k.txt" "$IMG_DIR/$k.png" --title "$k"; }
note_capture(){ local k="$1" t="$2" b="$3"; printf '%s\n' "$b" >"$LOG_DIR/$k.txt"; python3 scripts/text_to_png.py "$LOG_DIR/$k.txt" "$IMG_DIR/$k.png" --title "$t"; }
note_capture 01_script cron_script "#!/usr/bin/env bash
set -euo pipefail
TS=\$(date +%F_%H-%M-%S)
mkdir -p /var/backups/home
tar -czf /var/backups/home/home_backup_\${TS}.tar.gz \"$HOME\""
run_capture 02_install "sudo install -m 755 /dev/stdin /usr/local/bin/weekly_home_backup.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
TS=\$(date +%F_%H-%M-%S)
mkdir -p /var/backups/home
tar -czf /var/backups/home/home_backup_\${TS}.tar.gz /home
EOS
sudo sed -i '/weekly_home_backup.sh/d' /etc/crontab; echo '0 0 * * 0 root /usr/local/bin/weekly_home_backup.sh' | sudo tee -a /etc/crontab; tail -n 8 /etc/crontab"
cat > "$ROOT/report.json" <<EOF_JSON
{"title":"Отчёт по практической работа номер 6 ${REPORT_AUTHOR}","sections":[{"heading":"6. Скрипт архивации","image":"$IMG_DIR/01_script.png"},{"heading":"6. Запись в /etc/crontab","image":"$IMG_DIR/02_install.png"}]}
EOF_JSON
python3 scripts/build_pdf_report.py "$ROOT/report.json" "$ROOT/report.pdf"
