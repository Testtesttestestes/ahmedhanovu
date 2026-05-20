#!/usr/bin/env bash
set -euo pipefail

REPORT_AUTHOR="${REPORT_AUTHOR:-Миленькова Ивана}"
ROOT="reports/task5"
LOG_DIR="$ROOT/logs"
IMG_DIR="$ROOT/images"
mkdir -p "$LOG_DIR" "$IMG_DIR"

NEW_USER="${NEW_USER:-studentnew}"
OLD_USER="${OLD_USER:-$(id -un)}"
NEW_GROUP="${NEW_GROUP:-pktcap}"

run_capture() {
  local key="$1"; shift
  { echo "$ $*"; bash -lc "$*"; } >"$LOG_DIR/${key}.txt" 2>&1 || true
  python3 scripts/text_to_png.py "$LOG_DIR/${key}.txt" "$IMG_DIR/${key}.png" --title "$key"
}

run_capture 01_useradd "sudo useradd -m -s /bin/bash '${NEW_USER}' && id '${NEW_USER}' && getent passwd '${NEW_USER}'"
run_capture 02_first_file "sudo -u '${NEW_USER}' bash -lc 'echo first_owned_by_new_user > ~/first' && sudo install -o '${NEW_USER}' -g '${NEW_USER}' -m 600 ~'${NEW_USER}'/first /tmp/first && ls -l /tmp/first"
run_capture 03_second_file "echo second_owned_by_old_user > /tmp/second && sudo chown '${OLD_USER}:${OLD_USER}' /tmp/second && sudo chmod 600 /tmp/second && ls -l /tmp/second"
run_capture 04_sudoers_pkgmgr "sudo sh -c \"printf '%s\\n' '${OLD_USER} ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get, /usr/bin/dnf, /usr/bin/yum, /usr/bin/pacman' > /etc/sudoers.d/90-${OLD_USER}-pkgmgr\" && sudo chmod 440 /etc/sudoers.d/90-${OLD_USER}-pkgmgr && sudo visudo -cf /etc/sudoers.d/90-${OLD_USER}-pkgmgr"
run_capture 05_pkgmgr_vs_tcpdump "sudo -n apt-get -v || sudo -n dnf --version || sudo -n yum --version || sudo -n pacman --version; sudo -n tcpdump -D"
run_capture 06_new_user_denied_pkgmgr "sudo -u '${NEW_USER}' sudo -n apt-get -v || sudo -u '${NEW_USER}' sudo -n dnf --version || sudo -u '${NEW_USER}' sudo -n yum --version || sudo -u '${NEW_USER}' sudo -n pacman --version"
run_capture 07_groupadd_and_tcpdump "sudo groupadd -f '${NEW_GROUP}' && sudo usermod -aG '${NEW_GROUP}' '${OLD_USER}' && sudo usermod -aG '${NEW_GROUP}' '${NEW_USER}' && sudo sh -c \"printf '%%%s ALL=(ALL) NOPASSWD: /usr/sbin/tcpdump\\n' '${NEW_GROUP}' > /etc/sudoers.d/91-${NEW_GROUP}-tcpdump\" && sudo chmod 440 /etc/sudoers.d/91-${NEW_GROUP}-tcpdump && sudo visudo -cf /etc/sudoers.d/91-${NEW_GROUP}-tcpdump && getent group '${NEW_GROUP}'"
run_capture 08_tcpdump_both_users "sudo -n tcpdump -D ; sudo -u '${NEW_USER}' bash -lc 'id && sudo -n tcpdump -D'"

cat > "$ROOT/report.json" <<EOF_JSON
{"title":"Отчёт по практической работа номер 5 ${REPORT_AUTHOR}","sections":[
{"heading":"5.1 useradd","image":"$IMG_DIR/01_useradd.png"},
{"heading":"5.2 first + права","image":"$IMG_DIR/02_first_file.png"},
{"heading":"5.3 second + права","image":"$IMG_DIR/03_second_file.png"},
{"heading":"5.4 sudoers для пакетного менеджера","image":"$IMG_DIR/04_sudoers_pkgmgr.png"},
{"heading":"5.4 проверка package manager/tcpdump","image":"$IMG_DIR/05_pkgmgr_vs_tcpdump.png"},
{"heading":"5.4 новый пользователь denied","image":"$IMG_DIR/06_new_user_denied_pkgmgr.png"},
{"heading":"5.5 groupadd + sudoers tcpdump","image":"$IMG_DIR/07_groupadd_and_tcpdump.png"},
{"heading":"5.5 проверка tcpdump обоим","image":"$IMG_DIR/08_tcpdump_both_users.png"}
]}
EOF_JSON
python3 scripts/build_pdf_report.py "$ROOT/report.json" "$ROOT/report.pdf"
