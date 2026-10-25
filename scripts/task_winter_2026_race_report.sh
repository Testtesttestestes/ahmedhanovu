#!/usr/bin/env bash
set -euo pipefail

REPORT_AUTHOR="${REPORT_AUTHOR:-Миленькова Ивана}"
ROOT="reports/winter-2026-task1"
LOG_DIR="$ROOT/logs"
IMG_DIR="$ROOT/images"
RESULTS="$ROOT/results.json"
mkdir -p "$LOG_DIR" "$IMG_DIR"

python3 scripts/task_winter_2026_race_condition.py --workers 10 --increments 100000 --runs 5 --output "$RESULTS" > "$LOG_DIR/01_experiment.txt"
python3 scripts/text_to_png.py "$LOG_DIR/01_experiment.txt" "$IMG_DIR/01_experiment.png" --title "Результаты эксперимента"

python3 - "$RESULTS" "$ROOT/report.json" "$IMG_DIR/01_experiment.png" "$REPORT_AUTHOR" <<'PY'
import json, sys
from pathlib import Path

results = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
unsafe = results["unsafe"]
safe = results["mutex"]
expected = results["expected"]
unsafe_values = ", ".join(str(item["value"]) for item in unsafe)
safe_values = ", ".join(str(item["value"]) for item in safe)
unsafe_times = ", ".join(f'{item["seconds"]:.4f}' for item in unsafe)
safe_times = ", ".join(f'{item["seconds"]:.4f}' for item in safe)
manifest = {
  "title": "Отчёт по практической работа номер 1 (зима 2026) " + sys.argv[4],
  "subtitle": "Демонстрация race condition и исправление с помощью мьютекса.",
  "metadata": [
    {"label": "Потоки", "value": str(results["workers"])},
    {"label": "Инкрементов на поток", "value": str(results["increments_per_worker"])},
    {"label": "Ожидаемое значение", "value": str(expected)},
    {"label": "Язык", "value": "Python 3, threading"},
  ],
  "sections": [
    {"heading": "1. Постановка эксперимента", "body": [
      f'Запущены {results["workers"]} потоков, каждый выполняет {results["increments_per_worker"]} инкрементов. Ожидаемое значение: {expected}.',
      "В небезопасной версии чтение, увеличение и запись разделены; это неатомарная последовательность. Между чтением и записью поток может быть приостановлен.",
    ]},
    {"heading": "2. Версия без мьютекса", "body": [
      "Фактические значения по пяти запускам: " + unsafe_values + ". Они меньше ожидаемого, потому что несколько потоков могут прочитать одно и то же старое значение и затем записать одинаковый результат, теряя инкременты.",
      "Время (секунды): " + unsafe_times + ".",
    ], "image": sys.argv[3], "caption": "Вывод программы с результатами обеих версий."},
    {"heading": "3. Версия с мьютексом", "body": [
      "В защищённой версии операция изменения счётчика выполняется внутри threading.Lock. Фактические значения по пяти запускам: " + safe_values + ". Корректность всех запусков: " + ("да" if all(item["value"] == expected for item in safe) else "нет") + ".",
      "Время (секунды): " + safe_times + ". В этом эксперименте мьютекс работает быстрее, потому что небезопасная версия специально уступает планировщику через time.sleep(0), чтобы сделать гонку наблюдаемой. В реальном коде стоимость блокировки зависит от длительности критической секции и конкуренции.",
    ]},
    {"heading": "4. Вывод", "body": [
      "Race condition возникает из-за совместного доступа к изменяемому состоянию без синхронизации. Для корректного результата операции read-modify-write должны выполняться как единое защищённое действие; мьютекс обеспечивает это свойство.",
    ]},
  ],
}
Path(sys.argv[2]).write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
PY
python3 scripts/build_pdf_report.py "$ROOT/report.json" "$ROOT/report.pdf"
echo "Winter 2026 race-condition PDF report generated at $ROOT/report.pdf"
