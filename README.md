# FTP Repository Docker Setup

Этот проект создает Docker-контейнер с FTP-сервером (vsftpd) и репозиторием пакетов Debian/Ubuntu, управляемым через reprepro.

## Структура проекта

- `docker-compose.yaml` - конфигурация Docker Compose
- `Dockerfile` - образ с vsftpd и reprepro
- `vsftpd.conf` - конфигурация FTP-сервера
- `distributions` - конфигурация репозитория reprepro
- `start-ftp.sh` - скрипт инициализации репозитория
- `distr/` - папка с deb-пакетами для добавления в репозиторий
- `dist/` - папка, монтируемая в контейнер как репозиторий

## Использование

1. Поместите ваши `.deb` пакеты в папку `distr/`

2. Запустите контейнер:
   ```bash
   docker-compose up -d
   ```

3. Репозиторий будет доступен по адресу:
   ```
   ftp://localhost/astra/8.5.1.1150_x86-64
   ```

4. Для использования репозитория в системе добавьте в `/etc/apt/sources.list`:
   ```
   deb ftp://localhost/astra/8.5.1.1150_x86-64 main contrib non-free
   ```

5. Добавьте GPG ключ репозитория:
   ```bash
   # Ключ будет доступен по ftp://localhost/astra/repo_gpg.key
   curl ftp://localhost/astra/repo_gpg.key | sudo apt-key add -
   ```

6. Обновите список пакетов:
   ```bash
   sudo apt update
   ```

## Порты

- `21` - FTP control port
- `20` - FTP data port (активный режим)
- `21100-21110` - FTP пассивный режим

## Примечания

- Репозиторий автоматически инициализируется при первом запуске
- GPG ключ генерируется автоматически при первом запуске
- Пакеты из папки `distr/` автоматически добавляются в репозиторий при запуске
- Для добавления новых пакетов поместите их в `distr/` и перезапустите контейнер
