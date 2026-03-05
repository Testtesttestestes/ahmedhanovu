#!/usr/bin/env bash
set -euo pipefail

ROOT="reports/task2"
LOG_DIR="$ROOT/logs"
IMG_DIR="$ROOT/images"
WORK="$ROOT/workdir"
mkdir -p "$LOG_DIR" "$IMG_DIR" "$WORK"

run_capture() {
  local key="$1"; shift
  {
    echo "$ $*"
    bash -lc "$*"
  } >"$LOG_DIR/${key}.txt" 2>&1 || true
  python3 scripts/text_to_png.py "$LOG_DIR/${key}.txt" "$IMG_DIR/${key}.png" --title "$key"
}

cat > "$WORK/sample.txt" <<EOF
alpha
beta
gamma
alpha delta
EOF

run_capture 01_pwd 'pwd'
run_capture 02_cd "cd '$WORK' && pwd"
run_capture 03_ls "ls -la '$WORK'"
run_capture 04_mkdir "mkdir -p '$WORK/new_dir' && ls -la '$WORK'"
run_capture 05_touch "touch '$WORK/new_dir/file1.txt' && ls -la '$WORK/new_dir'"
run_capture 06_cat "cat '$WORK/sample.txt'"
run_capture 07_grep "grep alpha '$WORK/sample.txt'"
run_capture 08_cp "cp '$WORK/sample.txt' '$WORK/sample_copy.txt' && ls -la '$WORK'"
run_capture 09_mv "mv '$WORK/sample_copy.txt' '$WORK/sample_moved.txt' && ls -la '$WORK'"
run_capture 10_head "head -n 2 '$WORK/sample.txt'"
run_capture 11_tail "tail -n 2 '$WORK/sample.txt'"
run_capture 12_top 'top -b -n 1 | head -n 12'
run_capture 13_ps 'ps aux | head -n 10'
run_capture 14_date 'date'
run_capture 15_man 'man ls | head -n 20'
run_capture 16_kill "sleep 30 & pid=\$!; kill \$pid; echo Killed PID: \$pid"
run_capture 17_echo "echo 'Hello terminal commands'"
run_capture 18_chmod "chmod 640 '$WORK/sample_moved.txt' && ls -l '$WORK/sample_moved.txt'"
run_capture 19_find "find '$WORK' -maxdepth 2 -type f | sort"
run_capture 20_dd "dd if=/dev/zero of='$WORK/dd_test.img' bs=1M count=1 status=none && ls -lh '$WORK/dd_test.img'"
run_capture 21_pkg 'sudo apt-get --version | head -n 2 || yum --version | head -n 2 || dnf --version | head -n 2'

cat > "$ROOT/report.md" <<EOF
# Отчёт по заданию 2 — базовые команды терминала

| № | Команда | Краткое описание | Скриншот |
|---|---|---|---|
|1|pwd|Показывает текущую директорию.|![pwd](images/01_pwd.png)|
|2|cd|Переходит в другую директорию.|![cd](images/02_cd.png)|
|3|ls|Показывает содержимое каталога.|![ls](images/03_ls.png)|
|4|mkdir|Создаёт директорию.|![mkdir](images/04_mkdir.png)|
|5|touch|Создаёт пустой файл/обновляет метку времени.|![touch](images/05_touch.png)|
|6|cat|Выводит содержимое файла.|![cat](images/06_cat.png)|
|7|grep|Ищет строки по шаблону.|![grep](images/07_grep.png)|
|8|cp|Копирует файл/директорию.|![cp](images/08_cp.png)|
|9|mv|Перемещает или переименовывает.|![mv](images/09_mv.png)|
|10|head|Показывает начало файла.|![head](images/10_head.png)|
|11|tail|Показывает конец файла.|![tail](images/11_tail.png)|
|12|top|Показывает процессы и загрузку в реальном времени.|![top](images/12_top.png)|
|13|ps|Выводит список процессов.|![ps](images/13_ps.png)|
|14|date|Показывает текущие дату и время.|![date](images/14_date.png)|
|15|man|Открывает справку по команде.|![man](images/15_man.png)|
|16|kill|Отправляет сигнал процессу (например, завершение).|![kill](images/16_kill.png)|
|17|echo|Выводит текст/значения переменных.|![echo](images/17_echo.png)|
|18|chmod|Изменяет права доступа к файлу.|![chmod](images/18_chmod.png)|
|19|find|Ищет файлы и директории.|![find](images/19_find.png)|
|20|dd|Поблочное копирование/создание образов.|![dd](images/20_dd.png)|
|21|apt/yum/dnf|Менеджер пакетов (установка/обновление ПО).|![pkg](images/21_pkg.png)|

EOF

echo "Task 2 report generated at $ROOT/report.md"
