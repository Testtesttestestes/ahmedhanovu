# Автоматические отчёты по заданиям (GitHub Actions)

В репозитории настроены **9 отдельных workflow** (по одному на каждую практическую работу):

1. `Task 1 - VM and Linux install report`
2. `Task 2 - Terminal commands report`
3. `Task 3 - Filesystem image report`
4. `Task 4 - SSH and RDP remote access report`
5. `Task 5 - Users, permissions and sudo report`
6. `Task 6 - Crontab backup report`
7. `Task 7 - Process signals report`
8. `Task 8 - Journalctl report`
9. `Task 9 - Environment variables report`

Каждый workflow:
- запускается вручную (`workflow_dispatch`),
- выполняет набор команд для практической работы,
- формирует PNG-иллюстрации по выводу команд,
- собирает **красиво оформленный PDF-отчёт** с заголовком вида `Отчёт по практической работа номер {номер работы} Миленькова Ивана`,
- выгружает в артефакты **только `report.pdf`**, а не весь каталог с промежуточными файлами.

Имя автора задаётся прямо в workflow через переменную `REPORT_AUTHOR`, поэтому его можно легко заменить без редактирования shell-скриптов.

> Для задания 1 используется подход с cloud image + cloud-init (пользователь задаётся переменной `SURNAME`, по умолчанию `Milenkov`) и формируется команда запуска VM в QEMU.

## Зима 2026: iptables

- `Winter 2026 Task 6 - iptables basics report` (`scripts/task_winter_2026_iptables_basics_report.sh`): просмотр правил и таблиц, резервная копия `iptables-save`, очистка с политикой ACCEPT, блокировка ping с определённого IP, проверка с другой машины и удаление правила по номеру строки.
- `Winter 2026 Task 7 - iptables firewall report` (`scripts/task_winter_2026_firewall_report.sh`): политика DROP, loopback, ESTABLISHED/RELATED, SSH, HTTP/HTTPS, ICMP с лимитом, логирование `IPTABLES-DROP` и сохранение правил. Затем проверяются SSH и веб-сервер, выводятся `iptables -L -n -v` и `dmesg | grep IPTABLES-DROP`.

«ВМ» и «другая машина» здесь — два сетевых пространства имён (`netns vm` 10.200.0.1 и `netns client` 10.200.0.2), соединённые veth-парой (`scripts/task_winter_2026_netns_lib.sh`). Правила iptables применяются только внутри `netns vm`, сеть раннера не затрагивается.
