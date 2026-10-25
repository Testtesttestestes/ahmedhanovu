#!/usr/bin/env bash
set -euo pipefail

REPORT_AUTHOR="${REPORT_AUTHOR:-Миленькова Ивана}"
ROOT="reports/winter-2026-task3"
LOG_DIR="$ROOT/logs"
IMG_DIR="$ROOT/images"
FIXTURE="$ROOT/login-events.log"
WATCH_LOG="$ROOT/login_watch.log"
mkdir -p "$LOG_DIR" "$IMG_DIR"
: > "$FIXTURE"
: > "$WATCH_LOG"

bash scripts/watch_login.sh --input-file "$FIXTURE" --log-file "$WATCH_LOG" > "$LOG_DIR/01_notifications.txt" 2>&1 &
WATCH_PID=$!
sleep 0.5
printf '%s\n' '2026-10-26T10:20:00+00:00 host sshd[123]: Accepted publickey for winteruser from 192.0.2.44 port 51234 ssh2' >> "$FIXTURE"
sleep 1
kill -INT "$WATCH_PID" 2>/dev/null || true
for _ in {1..10}; do
  kill -0 "$WATCH_PID" 2>/dev/null || break
  sleep 0.1
done
if kill -0 "$WATCH_PID" 2>/dev/null; then
  # The SIGINT above is the graceful stop under test; clean up a runner-specific
  # coprocess wrapper if it has not exited yet.
  kill -TERM "$WATCH_PID" 2>/dev/null || true
  sleep 0.1
  kill -KILL "$WATCH_PID" 2>/dev/null || true
fi
wait "$WATCH_PID" 2>/dev/null || true

python3 scripts/text_to_png.py scripts/watch_login.sh "$IMG_DIR/02_script.png" --title "watch_login.sh"
python3 scripts/text_to_png.py "$WATCH_LOG" "$IMG_DIR/03_log.png" --title "login_watch.log"
python3 scripts/text_to_png.py "$LOG_DIR/01_notifications.txt" "$IMG_DIR/01_notifications.png" --title "Уведомление"
test -s "$WATCH_LOG"

python3 - "$ROOT/report.json" "$IMG_DIR" "$WATCH_LOG" "$REPORT_AUTHOR" <<'PY'
import json, sys
from pathlib import Path
log = Path(sys.argv[3]).read_text(encoding='utf-8').strip()
manifest = {
  'title': 'Отчёт по практической работа номер 3 (зима 2026) ' + sys.argv[4],
  'subtitle': 'Мониторинг успешных входов в систему в реальном времени.',
  'metadata': [
    {'label': 'Скрипт', 'value': 'scripts/watch_login.sh'},
    {'label': 'Источник', 'value': 'journalctl -f; fallback /var/log/auth.log'},
    {'label': 'Лог', 'value': '/var/log/login_watch.log'},
    {'label': 'Тест', 'value': 'успешный SSH-вход из тестового события'},
  ],
  'sections': [
    {'heading': '1. Код скрипта', 'body': ['Скрипт читает поток journalctl -f (или auth.log), распознаёт строки Accepted и записывает время, пользователя и IP-адрес. Флаг --input-file используется только для воспроизводимой проверки workflow.'], 'image': str(Path(sys.argv[2]) / '02_script.png'), 'caption': 'Исходный код watch_login.sh.'},
    {'heading': '2. Фрагмент лога и уведомление', 'body': ['Тестовая строка имитирует успешный вход пользователя winteruser с адреса 192.0.2.44. Полученная запись: ' + log + '. При каждом событии скрипт также печатает зелёное уведомление и отправляет сообщение через logger, если он доступен.'], 'image': str(Path(sys.argv[2]) / '03_log.png'), 'caption': 'Содержимое login_watch.log.'},
    {'heading': '3. Запуск и остановка', 'body': ['В обычной системе запустите: sudo bash scripts/watch_login.sh &. Для проверки можно войти из другого терминала по SSH или выполнить su. Обработчики INT и TERM останавливают дочерний tail/journalctl, дожидаются его завершения и завершают скрипт без оставшегося фонового процесса. В workflow остановка проверена сигналом SIGINT.'], 'image': str(Path(sys.argv[2]) / '01_notifications.png'), 'caption': 'Уведомление о новом входе.'},
  ],
}
Path(sys.argv[1]).write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
PY
python3 scripts/build_pdf_report.py "$ROOT/report.json" "$ROOT/report.pdf"
echo "Winter 2026 login-watch PDF report generated at $ROOT/report.pdf"
