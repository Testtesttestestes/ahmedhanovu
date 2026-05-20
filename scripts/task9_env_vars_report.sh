#!/usr/bin/env bash
set -euo pipefail

REPORT_AUTHOR="${REPORT_AUTHOR:-Миленькова Ивана}"
ROOT="reports/task9"
LOG_DIR="$ROOT/logs"
IMG_DIR="$ROOT/images"

mkdir -p "$LOG_DIR" "$IMG_DIR"

run_capture() {
  local key="$1"
  shift
  {
    echo "$ $*"
    bash -lc "$*"
  } >"$LOG_DIR/$key.txt" 2>&1 || true
  python3 scripts/text_to_png.py "$LOG_DIR/$key.txt" "$IMG_DIR/$key.png" --title "$key"
}

cat > "$ROOT/env_info.sh" <<'EOF_ENV'
#!/usr/bin/env bash
set -euo pipefail

echo "USER=${USER:-}"
echo "HOME=${HOME:-}"
echo "PATH=${PATH:-}"

LAB="linux_lab"
export LAB

"$(dirname "$0")/child.sh"
EOF_ENV

cat > "$ROOT/child.sh" <<'EOF_CHILD'
#!/usr/bin/env bash
set -euo pipefail

echo "LAB=${LAB:-}"
EOF_CHILD

chmod +x "$ROOT/env_info.sh" "$ROOT/child.sh"

run_capture 01_env_info "'$ROOT/env_info.sh'"
run_capture 02_child_direct "'$ROOT/child.sh'"
run_capture 03_combined "'$ROOT/env_info.sh'; echo '---'; '$ROOT/child.sh'"

cat > "$ROOT/report.json" <<EOF_JSON
{"title":"Отчёт по практической работа номер 9 ${REPORT_AUTHOR}","sections":[{"heading":"9.1 Скрипт env_info.sh: USER, HOME, PATH + export LAB + запуск child.sh","image":"$IMG_DIR/01_env_info.png"},{"heading":"9.2 Прямой запуск child.sh","image":"$IMG_DIR/02_child_direct.png"},{"heading":"9.3 Сравнение: через env_info.sh и напрямую","image":"$IMG_DIR/03_combined.png"}]}
EOF_JSON

python3 scripts/build_pdf_report.py "$ROOT/report.json" "$ROOT/report.pdf"
