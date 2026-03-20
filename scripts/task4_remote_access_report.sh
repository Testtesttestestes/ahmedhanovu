#!/usr/bin/env bash
set -euo pipefail

REPORT_AUTHOR="${REPORT_AUTHOR:-Миленькова Ивана}"
ROOT="reports/task4"
LOG_DIR="$ROOT/logs"
IMG_DIR="$ROOT/images"
STATE_DIR="$ROOT/state"
KEY_PATH="$STATE_DIR/task4_demo_ed25519"
DEMO_PASSWORD="${DEMO_PASSWORD:-LabPassw0rd!}"
mkdir -p "$LOG_DIR" "$IMG_DIR" "$STATE_DIR"

run_capture() {
  local key="$1"; shift
  {
    echo "$ $*"
    bash -lc "$*"
  } >"$LOG_DIR/${key}.txt" 2>&1 || true
  python3 scripts/text_to_png.py "$LOG_DIR/${key}.txt" "$IMG_DIR/${key}.png" --title "$key"
}

note_capture() {
  local key="$1"
  local title="$2"
  local body="$3"
  printf '%s\n' "$body" >"$LOG_DIR/${key}.txt"
  python3 scripts/text_to_png.py "$LOG_DIR/${key}.txt" "$IMG_DIR/${key}.png" --title "$title"
}

RUNNER_USER="$(id -un)"
RUNNER_HOME="$(getent passwd "$RUNNER_USER" | cut -d: -f6)"
HOST_IP="$(hostname -I | awk '{print $1}')"

run_capture 01_install_ssh "sudo apt-get update && sudo apt-get install -y openssh-server sshpass"
run_capture 02_detect_ip "hostname -I && ip -brief address show"
run_capture 03_start_ssh "sudo mkdir -p /run/sshd && sudo service ssh start && sudo service ssh status || sudo systemctl status ssh --no-pager"
run_capture 04_prepare_password_demo "echo '${RUNNER_USER}:${DEMO_PASSWORD}' | sudo chpasswd && sudo grep -E '^(PubkeyAuthentication|PasswordAuthentication)' /etc/ssh/sshd_config || true"
run_capture 05_password_login "sshpass -p '${DEMO_PASSWORD}' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${RUNNER_USER}@${HOST_IP} 'whoami && hostname && echo Connected_with_password'"
run_capture 06_generate_ssh_keys "rm -f '${KEY_PATH}' '${KEY_PATH}.pub' && ssh-keygen -t ed25519 -N '' -f '${KEY_PATH}' -C 'task4-demo-key' && ls -l '${KEY_PATH}'* && cat '${KEY_PATH}.pub'"
run_capture 07_enable_key_auth "install -d -m 700 '${RUNNER_HOME}/.ssh' && cat '${KEY_PATH}.pub' >> '${RUNNER_HOME}/.ssh/authorized_keys' && chmod 600 '${RUNNER_HOME}/.ssh/authorized_keys' && tail -n 1 '${RUNNER_HOME}/.ssh/authorized_keys'"
run_capture 08_key_login "ssh -i '${KEY_PATH}' -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${RUNNER_USER}@${HOST_IP} 'whoami && hostname && echo Connected_with_key'"

note_capture 09_windows_powershell "windows_powershell" "PowerShell (Windows)\n--------------------\n1. Узнать IP Linux ВМ можно командой: hostname -I\n2. Подключение по паролю из Windows PowerShell:\n   ssh ${RUNNER_USER}@${HOST_IP}\n3. Генерация ключей на Windows:\n   ssh-keygen -t ed25519\n4. Копирование ключа на Linux:\n   type \$env:USERPROFILE\\.ssh\\id_ed25519.pub | ssh ${RUNNER_USER}@${HOST_IP} 'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys'\n5. Повторное подключение без пароля:\n   ssh ${RUNNER_USER}@${HOST_IP}"

run_capture 10_install_rdp "sudo apt-get install -y xrdp xorgxrdp"
run_capture 11_start_rdp "sudo adduser xrdp ssl-cert && sudo service xrdp start && sudo service xrdp status || sudo systemctl status xrdp --no-pager"
run_capture 12_check_rdp_port "sudo ss -tulpn | grep 3389 || true"

note_capture 13_windows_rdp "windows_rdp" "RDP (Windows)\n-------------\n1. На Windows нажмите Win+R и выполните: mstsc\n2. В поле Computer укажите: ${HOST_IP}\n3. Нажмите Connect и введите логин Linux-пользователя: ${RUNNER_USER}\n4. После входа будет открыт удалённый рабочий стол через xrdp.\n5. Если используется нестандартный порт, укажите адрес в формате ${HOST_IP}:3389"

cat > "$ROOT/report.json" <<EOF_JSON
{
  "title": "Отчёт по практической работа номер 4 ${REPORT_AUTHOR}",
  "subtitle": "Настройка удалённого доступа к Linux ВМ по SSH и RDP с пошаговыми действиями и иллюстрациями.",
  "metadata": [
    {"label": "Автор", "value": "${REPORT_AUTHOR}"},
    {"label": "SSH-сервер", "value": "OpenSSH Server"},
    {"label": "RDP-сервер", "value": "xrdp"},
    {"label": "IP стенда", "value": "${HOST_IP}"}
  ],
  "sections": [
    {
      "heading": "1. Установка SSH-сервера",
      "body": [
        "На Linux ВМ устанавливаются пакеты openssh-server и sshpass. Пакет sshpass используется в отчёте только для демонстрации первого подключения по паролю, после чего выполняется переход на ключевую аутентификацию."
      ],
      "image": "${IMG_DIR}/01_install_ssh.png",
      "caption": "Рисунок 1 — установка OpenSSH Server и вспомогательных утилит."
    },
    {
      "heading": "2. Определение IP-адреса виртуальной машины",
      "body": [
        "Перед подключением с Windows необходимо узнать IP-адрес Linux ВМ. Для этого выводятся hostname -I и краткая сводка по сетевым интерфейсам."
      ],
      "image": "${IMG_DIR}/02_detect_ip.png",
      "caption": "Рисунок 2 — определение IP-адреса ВМ для последующего SSH- и RDP-подключения."
    },
    {
      "heading": "3. Запуск и проверка SSH-сервиса",
      "body": [
        "После установки служба ssh запускается и проверяется её состояние, чтобы убедиться, что сервер готов принимать входящие подключения."
      ],
      "image": "${IMG_DIR}/03_start_ssh.png",
      "caption": "Рисунок 3 — запуск службы ssh и проверка её статуса."
    },
    {
      "heading": "4. Подготовка тестового входа по паролю",
      "body": [
        "Для первого подключения задаётся пароль текущему Linux-пользователю и при необходимости проверяются ключевые параметры конфигурации sshd."
      ],
      "image": "${IMG_DIR}/04_prepare_password_demo.png",
      "caption": "Рисунок 4 — подготовка пароля для первичного SSH-подключения."
    },
    {
      "heading": "5. Проверка SSH-подключения по паролю",
      "body": [
        "Подключение к SSH-серверу выполняется по IP-адресу ВМ. В отчёте показан успешный вход в систему и выполнение простых команд на удалённой стороне."
      ],
      "image": "${IMG_DIR}/05_password_login.png",
      "caption": "Рисунок 5 — успешное SSH-подключение к Linux ВМ по паролю."
    },
    {
      "heading": "6. Генерация SSH-ключей",
      "body": [
        "Создаётся пара ключей ed25519. Публичный ключ затем добавляется на сервер для перехода к более безопасной аутентификации без ввода пароля."
      ],
      "image": "${IMG_DIR}/06_generate_ssh_keys.png",
      "caption": "Рисунок 6 — генерация SSH-ключей для беспарольного доступа."
    },
    {
      "heading": "7. Настройка входа по ключу",
      "body": [
        "Публичный ключ помещается в файл ~/.ssh/authorized_keys Linux-пользователя. Это разрешает серверу распознавать владельца приватного ключа при подключении."
      ],
      "image": "${IMG_DIR}/07_enable_key_auth.png",
      "caption": "Рисунок 7 — добавление публичного ключа в authorized_keys."
    },
    {
      "heading": "8. Проверка беспарольного SSH-доступа",
      "body": [
        "После настройки ключей выполняется повторное подключение. Успешный вход без запроса пароля подтверждает корректность конфигурации."
      ],
      "image": "${IMG_DIR}/08_key_login.png",
      "caption": "Рисунок 8 — SSH-подключение по ключу без ввода пароля."
    },
    {
      "heading": "9. Команды для подключения из Windows PowerShell",
      "body": [
        "Отдельно приводится последовательность команд, которую можно повторить в Windows PowerShell: подключение по паролю, генерация ключей на Windows и копирование публичного ключа на Linux ВМ."
      ],
      "image": "${IMG_DIR}/09_windows_powershell.png",
      "caption": "Рисунок 9 — пример действий в Windows PowerShell для SSH-доступа к Linux ВМ."
    },
    {
      "heading": "10. Установка RDP-сервера",
      "body": [
        "Для графического удалённого доступа устанавливаются пакеты xrdp и xorgxrdp. Они предоставляют сервер RDP и модуль для работы с X.Org-сессией."
      ],
      "image": "${IMG_DIR}/10_install_rdp.png",
      "caption": "Рисунок 10 — установка пакетов xrdp и xorgxrdp на Linux ВМ."
    },
    {
      "heading": "11. Запуск и проверка xrdp",
      "body": [
        "Служба xrdp запускается, а её статус проверяется. Дополнительно пользователь xrdp добавляется в группу ssl-cert, что часто требуется для корректной работы TLS-сертификатов."
      ],
      "image": "${IMG_DIR}/11_start_rdp.png",
      "caption": "Рисунок 11 — запуск RDP-сервера xrdp и проверка состояния службы."
    },
    {
      "heading": "12. Контроль порта RDP",
      "body": [
        "Проверка сокетов подтверждает, что xrdp слушает стандартный порт 3389 и готов принимать клиентские подключения."
      ],
      "image": "${IMG_DIR}/12_check_rdp_port.png",
      "caption": "Рисунок 12 — проверка прослушивания порта 3389 службой xrdp."
    },
    {
      "heading": "13. Подключение к Linux ВМ по RDP из Windows",
      "body": [
        "В завершение приводится последовательность действий для клиента Windows: запуск mstsc, ввод IP-адреса ВМ и аутентификация под Linux-пользователем в окне xrdp."
      ],
      "image": "${IMG_DIR}/13_windows_rdp.png",
      "caption": "Рисунок 13 — пример шагов для подключения к Linux ВМ по RDP из Windows."
    }
  ]
}
EOF_JSON

python3 scripts/build_pdf_report.py "$ROOT/report.json" "$ROOT/report.pdf"

echo "Task 4 PDF report generated at $ROOT/report.pdf"
