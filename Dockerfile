FROM debian:bookworm-slim

# Установка необходимых пакетов
RUN apt-get update && \
    apt-get install -y \
    vsftpd \
    reprepro \
    gnupg2 \
    curl \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Создание директорий для репозитория
RUN mkdir -p /srv/ftp/onec/conf && \
    mkdir -p /srv/ftp/onec/db && \
    mkdir -p /var/run/vsftpd/empty

# Копирование конфигурационных файлов
COPY vsftpd.conf /etc/vsftpd.conf
COPY distributions /srv/ftp/onec/conf/distributions
COPY onec-repo-add.sh /srv/ftp/onec/onec-repo-add.sh
COPY start-ftp.sh /usr/local/bin/start-ftp.sh

# Установка прав на скрипт
RUN chmod +x /usr/local/bin/start-ftp.sh

# Создание пользователя для FTP (если нужен не анонимный доступ)
RUN useradd -m -s /bin/bash ftpuser || true

# Открытие портов
EXPOSE 21 20 21100-21110

# Запуск скрипта инициализации
CMD ["/usr/local/bin/start-ftp.sh"]
