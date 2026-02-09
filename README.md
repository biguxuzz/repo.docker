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
   ftp://edu-ks-beringpro.1cit.com/onec/8.5.1.1150_x86-64
   ```

4. Для добавления репозитория в систему используйте автоматический скрипт:
   ```bash
   # Скачайте скрипт с FTP сервера
   curl ftp://edu-ks-beringpro.1cit.com/onec/onec-repo-add.sh -o onec-repo-add.sh
   
   # Запустите скрипт (требуются права root)
   sudo bash onec-repo-add.sh
   ```
   
   Скрипт автоматически:
   - Определит вашу операционную систему
   - Добавит репозиторий в систему
   - Импортирует GPG ключ репозитория
   - Обновит список пакетов

   **Альтернативный способ (ручное добавление):**
   
   Если вы предпочитаете добавить репозиторий вручную:
   ```bash
   # Добавьте репозиторий в /etc/apt/sources.list.d/onec-enterprise.list
   echo "deb ftp://edu-ks-beringpro.1cit.com/onec/8.5.1.1150_x86-64 main contrib non-free non-free-firmware" | sudo tee /etc/apt/sources.list.d/onec-enterprise.list
   
   # Добавьте GPG ключ
   curl ftp://edu-ks-beringpro.1cit.com/onec/repo_gpg.key | sudo apt-key add -
   
   # Обновите список пакетов
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
- Скрипт `onec-repo-add.sh` автоматически генерируется с встроенным GPG ключом и доступен на FTP сервере
- Для добавления новых пакетов поместите их в `distr/` и перезапустите контейнер
