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
