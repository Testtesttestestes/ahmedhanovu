#!/usr/bin/env bash
set -euo pipefail

REPORT_AUTHOR="${REPORT_AUTHOR:-Миленькова Ивана}"
ROOT="reports/winter-2026-task5"
LOG_DIR="$ROOT/logs"
IMG_DIR="$ROOT/images"
DATA="$ROOT/employees.csv"
mkdir -p "$LOG_DIR" "$IMG_DIR"
cat > "$DATA" <<'EOF'
Имя,Отдел,Продажи
Иван,Маркетинг,12000
Мария,Продажи,25000
Алексей,Маркетинг,9000
Ольга,Продажи,31000
Дмитрий,Поддержка,7000
EOF

{
  echo '$ awk -F, ... employees.csv  # сотрудники отдела Продажи'
  awk -F, 'NR > 1 && $2 == "Продажи" { print $0 }' "$DATA"
  echo
  echo '$ awk -F, ... employees.csv  # общая сумма продаж'
  awk -F, 'NR > 1 { sum += $3 } END { print sum }' "$DATA"
  echo
  echo '$ awk -F, ... employees.csv  # средняя зарплата Маркетинга'
  awk -F, 'NR > 1 && $2 == "Маркетинг" { sum += $3; count++ } END { printf "%.2f\n", sum / count }' "$DATA"
  echo
  echo '$ awk ... | sort -t, -k3,3nr  # продажи выше 10000'
  awk -F, 'NR > 1 && $3 > 10000 { print $0 }' "$DATA" | sort -t, -k3,3nr
} > "$LOG_DIR/01_awk.txt"
python3 scripts/text_to_png.py "$LOG_DIR/01_awk.txt" "$IMG_DIR/01_awk.png" --title "Команды awk и результаты"

python3 - "$ROOT/report.json" "$IMG_DIR/01_awk.png" "$REPORT_AUTHOR" <<'PY'
import json, sys
from pathlib import Path
manifest = {
  'title': 'Отчёт по практической работа номер 5 (зима 2026) ' + sys.argv[3],
  'subtitle': 'Фильтрация и расчёты по CSV с помощью awk.',
  'metadata': [
    {'label': 'Файл', 'value': 'reports/winter-2026-task5/employees.csv'},
    {'label': 'Инструмент', 'value': 'awk -F,'},
    {'label': 'Сумма продаж', 'value': '84 000'},
    {'label': 'Среднее Маркетинга', 'value': '10 500.00'},
  ],
  'sections': [
    {'heading': '1. Исходные данные и выборка', 'body': ['Создан CSV с полями Имя, Отдел, Продажи. Условие $2 == "Продажи" выводит Марию и Ольгу.'], 'image': sys.argv[2], 'caption': 'Команды awk и полный фрагмент результатов.'},
    {'heading': '2. Итоги и сортировка', 'body': ['Сумма третьего столбца равна 84000. Среднее для отдела Маркетинг: (12000 + 9000) / 2 = 10500. Выборка с продажами выше 10000 отсортирована по третьему столбцу по убыванию: Ольга, Мария, Иван.']},
  ],
}
Path(sys.argv[1]).write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
PY
python3 scripts/build_pdf_report.py "$ROOT/report.json" "$ROOT/report.pdf"
echo "Winter 2026 awk PDF report generated at $ROOT/report.pdf"
