#!/usr/bin/env bash
set -euo pipefail

REPORT_AUTHOR="${REPORT_AUTHOR:-Миленькова Ивана}"
ROOT="reports/task5_8"
LOG_DIR="$ROOT/logs"
IMG_DIR="$ROOT/images"
mkdir -p "$LOG_DIR" "$IMG_DIR"

NEW_USER="${NEW_USER:-studentnew}"
OLD_USER="${OLD_USER:-$(id -un)}"
NEW_GROUP="${NEW_GROUP:-pktcap}"

run_capture() {
  local key="$1"; shift
  {
    echo "$ $*"
    bash -lc "$*"
  } >"$LOG_DIR/${key}.txt" 2>&1 || true
  python3 scripts/text_to_png.py "$LOG_DIR/${key}.txt" "$IMG_DIR/${key}.png" --title "$key"
}

note_capture() {
  local key="$1" title="$2" body="$3"
  printf '%s\n' "$body" >"$LOG_DIR/${key}.txt"
  python3 scripts/text_to_png.py "$LOG_DIR/${key}.txt" "$IMG_DIR/${key}.png" --title "$title"
}

# Task 5
run_capture 01_useradd "sudo useradd -m -s /bin/bash '${NEW_USER}' && id '${NEW_USER}' && getent passwd '${NEW_USER}'"
run_capture 02_first_file "sudo -u '${NEW_USER}' bash -lc 'echo first_owned_by_new_user > ~/first' && sudo install -o '${NEW_USER}' -g '${NEW_USER}' -m 600 ~'${NEW_USER}'/first /tmp/first && ls -l /tmp/first"
run_capture 03_second_file "echo second_owned_by_old_user > /tmp/second && sudo chown '${OLD_USER}:${OLD_USER}' /tmp/second && sudo chmod 600 /tmp/second && ls -l /tmp/second"
run_capture 04_sudoers_pkgmgr "sudo sh -c \"printf '%s\\n' '${OLD_USER} ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get, /usr/bin/dnf, /usr/bin/yum, /usr/bin/pacman' > /etc/sudoers.d/90-${OLD_USER}-pkgmgr\" && sudo chmod 440 /etc/sudoers.d/90-${OLD_USER}-pkgmgr && sudo visudo -cf /etc/sudoers.d/90-${OLD_USER}-pkgmgr"
run_capture 05_pkgmgr_vs_tcpdump "sudo -n apt-get -v || sudo -n dnf --version || sudo -n yum --version || sudo -n pacman --version; sudo -n tcpdump -D"
run_capture 06_new_user_denied_pkgmgr "sudo -u '${NEW_USER}' sudo -n apt-get -v || sudo -u '${NEW_USER}' sudo -n dnf --version || sudo -u '${NEW_USER}' sudo -n yum --version || sudo -u '${NEW_USER}' sudo -n pacman --version"
run_capture 07_groupadd_and_tcpdump "sudo groupadd -f '${NEW_GROUP}' && sudo usermod -aG '${NEW_GROUP}' '${OLD_USER}' && sudo usermod -aG '${NEW_GROUP}' '${NEW_USER}' && sudo sh -c \"printf '%%%s ALL=(ALL) NOPASSWD: /usr/sbin/tcpdump\\n' '${NEW_GROUP}' > /etc/sudoers.d/91-${NEW_GROUP}-tcpdump\" && sudo chmod 440 /etc/sudoers.d/91-${NEW_GROUP}-tcpdump && sudo visudo -cf /etc/sudoers.d/91-${NEW_GROUP}-tcpdump && getent group '${NEW_GROUP}'"
run_capture 08_tcpdump_both_users "sudo -n tcpdump -D ; sudo -u '${NEW_USER}' bash -lc 'id && sudo -n tcpdump -D'"

# Task 6
note_capture 09_crontab_script "cron_script" "#!/usr/bin/env bash\nset -euo pipefail\nTS=\$(date +%F_%H-%M-%S)\nmkdir -p /var/backups/home\ntar -czf /var/backups/home/home_backup_\${TS}.tar.gz \"$HOME\""
run_capture 10_crontab_install "echo '0 0 * * 0 root /usr/local/bin/weekly_home_backup.sh' | sudo tee -a /etc/crontab && tail -n 5 /etc/crontab"

# Task 7
run_capture 11_start_stress "nohup bash -lc 'while :; do :; done' >/tmp/cpu_stress.log 2>&1 & echo $! > /tmp/stress.pid; cat /tmp/stress.pid"
run_capture 12_find_pid "ps -eo pid,ppid,user,cmd | grep -E 'while :; do :; done|cpu_stress' | grep -v grep"
run_capture 13_top_usage "PID=\$(cat /tmp/stress.pid); top -b -n 1 -p \"$PID\""
run_capture 14_ps_before_kill "ps -fp \"$(cat /tmp/stress.pid)\""
run_capture 15_sigterm_then_kill "PID=\$(cat /tmp/stress.pid); kill -TERM \"$PID\"; sleep 1; ps -p \"$PID\" || true; if ps -p \"$PID\" >/dev/null; then kill -KILL \"$PID\"; fi"
run_capture 16_ps_after_kill "ps -p \"$(cat /tmp/stress.pid)\" || true"

# Task 8
run_capture 17_journal_last20 "journalctl -n 20 --no-pager"
run_capture 18_ssh_logs "journalctl -u ssh -u sshd --no-pager | tail -n 50"
run_capture 19_enable_ssh_service "sudo systemctl enable ssh || sudo systemctl enable sshd; sudo systemctl restart ssh || sudo systemctl restart sshd; systemctl is-enabled ssh || systemctl is-enabled sshd"
run_capture 20_last_hour "journalctl --since '1 hour ago' --no-pager | tail -n 80"
run_capture 21_last_boot_to_file "journalctl -b --no-pager > '$ROOT/last_boot.log' && wc -l '$ROOT/last_boot.log' && tail -n 20 '$ROOT/last_boot.log'"
run_capture 22_errors_in_boot "grep -i 'error' '$ROOT/last_boot.log' | tail -n 50 || true"

cat > "$ROOT/report.json" <<EOF_JSON
{
  "title": "Отчёт по практической работа номер 5-8 ${REPORT_AUTHOR}",
  "subtitle": "Пользователи и права, cron-архивация, процессы и сигналы, анализ systemd journal.",
  "sections": [
    {"heading":"Задание 5.1 — создание пользователя","image":"$IMG_DIR/01_useradd.png"},
    {"heading":"Задание 5.2 — файл first только для нового пользователя","image":"$IMG_DIR/02_first_file.png"},
    {"heading":"Задание 5.3 — файл second только для старого пользователя","image":"$IMG_DIR/03_second_file.png"},
    {"heading":"Задание 5.4 — пакетный менеджер без пароля только старому пользователю","image":"$IMG_DIR/04_sudoers_pkgmgr.png"},
    {"heading":"Задание 5.4 — проверка package manager vs tcpdump","image":"$IMG_DIR/05_pkgmgr_vs_tcpdump.png"},
    {"heading":"Задание 5.4 — новый пользователь не может без пароля","image":"$IMG_DIR/06_new_user_denied_pkgmgr.png"},
    {"heading":"Задание 5.5 — группа и запуск tcpdump без пароля","image":"$IMG_DIR/07_groupadd_and_tcpdump.png"},
    {"heading":"Задание 5.5 — проверка tcpdump для обоих","image":"$IMG_DIR/08_tcpdump_both_users.png"},
    {"heading":"Задание 6 — скрипт архивирования","image":"$IMG_DIR/09_crontab_script.png"},
    {"heading":"Задание 6 — запись в /etc/crontab","image":"$IMG_DIR/10_crontab_install.png"},
    {"heading":"Задание 7.1-7.2 — фоновая нагрузка и PID","image":"$IMG_DIR/12_find_pid.png"},
    {"heading":"Задание 7.3 — потребление ресурсов","image":"$IMG_DIR/13_top_usage.png"},
    {"heading":"Задание 7.4 — завершение SIGTERM/SIGKILL","image":"$IMG_DIR/15_sigterm_then_kill.png"},
    {"heading":"Задание 7 — ps до и после","image":"$IMG_DIR/14_ps_before_kill.png"},
    {"heading":"Задание 7 — ps после завершения","image":"$IMG_DIR/16_ps_after_kill.png"},
    {"heading":"Задание 8.1 — последние 20 строк journal","image":"$IMG_DIR/17_journal_last20.png"},
    {"heading":"Задание 8.2 — сообщения ssh и автозапуск","image":"$IMG_DIR/18_ssh_logs.png"},
    {"heading":"Задание 8.2 — enable/restart ssh","image":"$IMG_DIR/19_enable_ssh_service.png"},
    {"heading":"Задание 8.3 — журнал за последний час","image":"$IMG_DIR/20_last_hour.png"},
    {"heading":"Задание 8.3.1 — сохранение последней загрузки","image":"$IMG_DIR/21_last_boot_to_file.png"},
    {"heading":"Задание 8.3.2 — строки с error","image":"$IMG_DIR/22_errors_in_boot.png"}
  ]
}
EOF_JSON

python3 scripts/build_pdf_report.py "$ROOT/report.json" "$ROOT/report.pdf"
echo "Task 5-8 PDF report generated at $ROOT/report.pdf"
