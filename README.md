# Автоматические отчёты по заданиям (GitHub Actions)

В репозитории добавлены **3 отдельных workflow** (по одному на каждое задание):

1. `Task 1 - VM and Linux install report`
2. `Task 2 - Terminal commands report`
3. `Task 3 - Filesystem image report`

Каждый workflow:
- запускается вручную (`workflow_dispatch`),
- выполняет набор команд,
- формирует отчёт в `reports/taskX/report.md`,
- прикладывает артефакт с отчётом и «скриншотами» вывода команд (`images/*.png`).

> Для задания 1 используется подход с cloud image + cloud-init (пользователь задаётся переменной `SURNAME`, по умолчанию `Ivanov`) и формируется команда запуска VM в QEMU.
