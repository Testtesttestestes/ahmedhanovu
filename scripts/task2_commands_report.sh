#!/usr/bin/env bash
set -euo pipefail

REPORT_AUTHOR="${REPORT_AUTHOR:-Миленькова Ивана}"
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

cat > "$ROOT/report.json" <<EOF
{
  "title": "Отчёт по практической работа номер 2 ${REPORT_AUTHOR}",
  "subtitle": "Демонстрация базовых команд терминала Linux с краткими пояснениями и иллюстрациями.",
  "metadata": [
    {"label": "Автор", "value": "${REPORT_AUTHOR}"},
    {"label": "Количество команд", "value": "21"},
    {"label": "Среда", "value": "GitHub Actions / Ubuntu runner"}
  ],
  "sections": [
    {"heading": "1. Навигация и работа с каталогами","body": ["Команды pwd, cd, ls, mkdir и touch показывают текущую директорию, переход между каталогами и создание новых объектов в файловой системе."],"image": "${IMG_DIR}/01_pwd.png","caption": "Рисунок 1 — определение текущего каталога командой pwd."},
    {"heading": "2. Переход в рабочий каталог","body": ["Команда cd переводит оболочку в каталог с подготовленными учебными файлами, где выполняются дальнейшие примеры."],"image": "${IMG_DIR}/02_cd.png","caption": "Рисунок 2 — переход в рабочий каталог при помощи cd."},
    {"heading": "3. Просмотр содержимого каталога","body": ["Команда ls -la выводит полный список файлов и служебные атрибуты объектов в каталоге."],"image": "${IMG_DIR}/03_ls.png","caption": "Рисунок 3 — содержимое каталога, полученное с помощью ls -la."},
    {"heading": "4. Создание новой директории","body": ["Команда mkdir подготавливает новый каталог для хранения вспомогательных файлов примера."],"image": "${IMG_DIR}/04_mkdir.png","caption": "Рисунок 4 — создание подкаталога командой mkdir."},
    {"heading": "5. Создание файла","body": ["Команда touch создаёт пустой файл file1.txt и обновляет время изменения объекта."],"image": "${IMG_DIR}/05_touch.png","caption": "Рисунок 5 — создание файла в новой директории командой touch."},
    {"heading": "6. Вывод содержимого файла","body": ["Команда cat печатает содержимое подготовленного текстового файла в стандартный вывод."],"image": "${IMG_DIR}/06_cat.png","caption": "Рисунок 6 — вывод содержимого sample.txt с помощью cat."},
    {"heading": "7. Поиск по шаблону","body": ["Команда grep отбирает строки, содержащие слово alpha, и помогает быстро фильтровать текстовые данные."],"image": "${IMG_DIR}/07_grep.png","caption": "Рисунок 7 — поиск строк по шаблону через grep."},
    {"heading": "8. Копирование файла","body": ["Команда cp создаёт копию исходного файла и демонстрирует базовые операции копирования данных."],"image": "${IMG_DIR}/08_cp.png","caption": "Рисунок 8 — копирование файла sample.txt при помощи cp."},
    {"heading": "9. Перемещение и переименование","body": ["Команда mv переносит файл и одновременно меняет его имя на sample_moved.txt."],"image": "${IMG_DIR}/09_mv.png","caption": "Рисунок 9 — перемещение и переименование файла командой mv."},
    {"heading": "10. Просмотр начала файла","body": ["Команда head удобна для быстрого чтения первых строк большого файла."],"image": "${IMG_DIR}/10_head.png","caption": "Рисунок 10 — просмотр первых строк sample.txt через head."},
    {"heading": "11. Просмотр конца файла","body": ["Команда tail показывает последние строки файла и используется для контроля изменений или журналов."],"image": "${IMG_DIR}/11_tail.png","caption": "Рисунок 11 — просмотр последних строк файла через tail."},
    {"heading": "12. Мониторинг процессов в реальном времени","body": ["Команда top в пакетном режиме демонстрирует состояние процессора, памяти и активных процессов системы."],"image": "${IMG_DIR}/12_top.png","caption": "Рисунок 12 — снимок системной нагрузки, полученный командой top."},
    {"heading": "13. Список процессов","body": ["Команда ps aux выводит перечень запущенных процессов вместе с их идентификаторами и параметрами запуска."],"image": "${IMG_DIR}/13_ps.png","caption": "Рисунок 13 — список процессов, сформированный командой ps aux."},
    {"heading": "14. Текущая дата и время","body": ["Команда date позволяет быстро получить системные дату и время на момент выполнения сценария."],"image": "${IMG_DIR}/14_date.png","caption": "Рисунок 14 — вывод текущих даты и времени через date."},
    {"heading": "15. Встроенная справка","body": ["Команда man ls открывает руководство пользователя и показывает, как получать документацию по утилитам Linux."],"image": "${IMG_DIR}/15_man.png","caption": "Рисунок 15 — фрагмент справочной страницы man ls."},
    {"heading": "16. Управление процессами","body": ["Команда kill завершает тестовый процесс sleep по его PID и демонстрирует отправку сигналов."],"image": "${IMG_DIR}/16_kill.png","caption": "Рисунок 16 — завершение процесса при помощи kill."},
    {"heading": "17. Вывод пользовательского текста","body": ["Команда echo используется для печати строк и значений переменных окружения."],"image": "${IMG_DIR}/17_echo.png","caption": "Рисунок 17 — вывод пользовательского сообщения командой echo."},
    {"heading": "18. Изменение прав доступа","body": ["Команда chmod задаёт файлу новые права и показывает их обновлённое состояние."],"image": "${IMG_DIR}/18_chmod.png","caption": "Рисунок 18 — изменение прав доступа через chmod."},
    {"heading": "19. Поиск файлов","body": ["Команда find рекурсивно находит файлы в рабочем каталоге и помогает быстро получить структуру проекта."],"image": "${IMG_DIR}/19_find.png","caption": "Рисунок 19 — поиск файлов с использованием find."},
    {"heading": "20. Создание бинарного файла","body": ["Команда dd создаёт тестовый образ заданного размера и часто применяется при работе с устройствами и образами дисков."],"image": "${IMG_DIR}/20_dd.png","caption": "Рисунок 20 — создание тестового образа командой dd."},
    {"heading": "21. Работа с пакетным менеджером","body": ["Вывод apt-get --version показывает наличие менеджера пакетов и служит примером проверки инструментов установки ПО."],"image": "${IMG_DIR}/21_pkg.png","caption": "Рисунок 21 — пример проверки пакетного менеджера в среде выполнения."}
  ]
}
EOF

python3 scripts/build_pdf_report.py "$ROOT/report.json" "$ROOT/report.pdf"

echo "Task 2 PDF report generated at $ROOT/report.pdf"
