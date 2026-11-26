#!/usr/bin/env bash
set -euo pipefail

REPORT_AUTHOR="${REPORT_AUTHOR:-Миленькова Ивана}"
STUDENT_NAME="${STUDENT_NAME:-Иван}"
CONTAINER="${CONTAINER:-nginx-ivan}"
ROOT="reports/winter-2026-task8"
LOG_DIR="$ROOT/logs"
IMG_DIR="$ROOT/images"
FONT="/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
rm -rf "$ROOT"
mkdir -p "$LOG_DIR" "$IMG_DIR"

DOCKER=(docker)
docker info >/dev/null 2>&1 || DOCKER=(sudo docker)
d() { "${DOCKER[@]}" "$@"; }
# Печатает команду и её вывод, ошибки не прерывают сбор отчёта.
run() {
  echo "\$ $*"
  "$@" 2>&1 || true
  echo
}

cleanup() { d rm -f "$CONTAINER" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

# --- 1. Установка Docker
{
  if ! command -v docker >/dev/null 2>&1; then
    echo "\$ sudo apt-get install -y docker.io"
    sudo apt-get install -y docker.io 2>&1 | tail -3
    sudo systemctl enable --now docker 2>&1 || true
  else
    echo "# Docker already installed. Install command on a clean Ubuntu VM:"
    echo "#   sudo apt-get update && sudo apt-get install -y docker.io"
    echo "#   sudo systemctl enable --now docker && sudo usermod -aG docker \$USER"
    echo
  fi
  run docker --version
  echo "\$ sudo docker info --format 'Server {{.ServerVersion}}, {{.OperatingSystem}}, storage {{.Driver}}'"
  d info --format 'Server {{.ServerVersion}}, {{.OperatingSystem}}, storage {{.Driver}}' 2>&1
  echo
  echo "\$ systemctl is-active docker"
  systemctl is-active docker 2>&1 || true
} > "$LOG_DIR/01_install.txt"

# --- 2. Официальный образ nginx
{
  echo "\$ docker pull nginx"
  d pull nginx 2>&1
  echo
  echo "\$ docker images nginx"
  d images nginx 2>&1
} > "$LOG_DIR/02_pull.txt"

# --- 3. Запуск с пробросом 8080 -> 80
{
  echo "\$ docker run -d --name $CONTAINER -p 8080:80 nginx"
  d run -d --name "$CONTAINER" -p 8080:80 nginx 2>&1
  sleep 2
  echo
  echo "\$ docker ps"
  d ps 2>&1
  echo
  echo "\$ docker port $CONTAINER"
  d port "$CONTAINER" 2>&1
} > "$LOG_DIR/03_run_ps.txt"

for _ in $(seq 20); do curl -fs http://localhost:8080/ >/dev/null && break; sleep 1; done

# --- 4. Проверка работоспособности
{
  echo "\$ curl -I http://localhost:8080"
  curl -sS -I http://localhost:8080 2>&1
  echo "\$ curl -s http://localhost:8080 | grep -i '<title>'"
  curl -s http://localhost:8080 | grep -i '<title>' || true
} > "$LOG_DIR/04_curl_default.txt"
curl -s http://localhost:8080 | grep -q 'Welcome to nginx'

# --- 5. Кастомная страница внутри контейнера и перезапуск
PAGE="<!DOCTYPE html>
<html lang=\"ru\">
<head><meta charset=\"utf-8\"><title>$STUDENT_NAME</title></head>
<body><h1>Привет! Меня зовут $STUDENT_NAME</h1><p>Страница создана внутри контейнера nginx.</p></body>
</html>"
{
  echo "# interactive way: docker exec -it $CONTAINER bash"
  echo "#   root@container:/# cat > /usr/share/nginx/html/index.html   (paste page, Ctrl+D)"
  echo "#   root@container:/# exit"
  echo
  echo "\$ docker exec -i $CONTAINER sh -c 'cat > /usr/share/nginx/html/index.html' <<'HTML'"
  echo "$PAGE"
  echo "HTML"
  printf '%s\n' "$PAGE" | d exec -i "$CONTAINER" sh -c 'cat > /usr/share/nginx/html/index.html'
  echo
  run "${DOCKER[@]}" exec "$CONTAINER" ls -l /usr/share/nginx/html/
  echo "\$ docker exec $CONTAINER cat /usr/share/nginx/html/index.html"
  d exec "$CONTAINER" cat /usr/share/nginx/html/index.html
  echo
  echo "\$ docker restart $CONTAINER"
  d restart "$CONTAINER" 2>&1
  sleep 2
  echo
  echo "\$ docker ps"
  d ps 2>&1
} > "$LOG_DIR/05_exec.txt"

for _ in $(seq 20); do curl -fs http://localhost:8080/ >/dev/null && break; sleep 1; done

{
  echo "\$ curl -i http://localhost:8080   # after restart"
  curl -sS -i http://localhost:8080 2>&1
} > "$LOG_DIR/06_custom_page.txt"
grep -q "Меня зовут $STUDENT_NAME" "$LOG_DIR/06_custom_page.txt"

declare -A TITLES=(
  [01_install]="Установка Docker"
  [02_pull]="docker pull nginx"
  [03_run_ps]="docker run -p 8080:80 и docker ps"
  [04_curl_default]="curl: стандартная страница nginx"
  [05_exec]="docker exec: создание index.html и перезапуск"
  [06_custom_page]="curl: кастомная страница после перезапуска"
)
for name in "${!TITLES[@]}"; do
  python3 scripts/text_to_png.py "$LOG_DIR/$name.txt" "$IMG_DIR/$name.png" --title "${TITLES[$name]}" --font "$FONT"
done

python3 - "$ROOT/report.json" "$IMG_DIR" "$REPORT_AUTHOR" "$STUDENT_NAME" "$CONTAINER" <<'PY'
import json, sys
from pathlib import Path
out, img, author, name, cont = sys.argv[1:]
i = lambda n: str(Path(img) / f'{n}.png')
manifest = {
  'title': 'Отчёт по практической работа номер 8 (зима 2026) ' + author,
  'subtitle': 'Docker: запуск официального образа nginx и кастомная страница.',
  'metadata': [
    {'label': 'Образ', 'value': 'nginx (официальный, Docker Hub)'},
    {'label': 'Контейнер', 'value': cont},
    {'label': 'Порты', 'value': 'хост 8080 -> контейнер 80'},
    {'label': 'Страница', 'value': f'/usr/share/nginx/html/index.html с именем «{name}»'},
  ],
  'sections': [
    {'heading': '1. Установка Docker', 'body': ['На Ubuntu Docker ставится командами sudo apt-get install -y docker.io и sudo systemctl enable --now docker. Версии клиента и сервера подтверждают, что демон запущен.'], 'image': i('01_install'), 'caption': 'docker --version и docker info.'},
    {'heading': '2. Официальный образ nginx', 'body': ['Команда docker pull nginx скачивает образ nginx:latest из Docker Hub; docker images показывает его в локальном хранилище.'], 'image': i('02_pull'), 'caption': 'Скачивание образа.'},
    {'heading': '3. Запуск контейнера и docker ps', 'body': [f'docker run -d --name {cont} -p 8080:80 nginx запускает контейнер в фоне. В выводе docker ps в столбце PORTS видно 0.0.0.0:8080->80/tcp.'], 'image': i('03_run_ps'), 'caption': 'Вывод docker run, docker ps и docker port.'},
    {'heading': '4. Проверка работоспособности (curl)', 'body': ['curl -I http://localhost:8080 возвращает HTTP/1.1 200 OK и заголовок Server: nginx, страница содержит "Welcome to nginx!".'], 'image': i('04_curl_default'), 'caption': 'Стандартная страница nginx.'},
    {'heading': '5. docker exec: создание index.html', 'body': [f'Внутри контейнера (docker exec) перезаписан файл /usr/share/nginx/html/index.html страницей с именем «{name}», затем выполнен docker restart {cont}. Файл хранится в записываемом слое контейнера, поэтому сохраняется при перезапуске (но не при пересоздании контейнера).'], 'image': i('05_exec'), 'caption': 'Команда docker exec, содержимое файла и перезапуск.'},
    {'heading': '6. Кастомная страница', 'body': [f'После перезапуска curl http://localhost:8080 возвращает созданную страницу: «Привет! Меня зовут {name}».'], 'image': i('06_custom_page'), 'caption': 'Содержимое кастомной страницы.'},
  ],
}
Path(out).write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
PY
python3 scripts/build_pdf_report.py "$ROOT/report.json" "$ROOT/report.pdf"
echo "Winter 2026 docker nginx PDF report generated at $ROOT/report.pdf"
