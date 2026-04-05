FROM debian:bookworm-slim

# Установка необходимых пакетов
RUN apt-get update && \
    apt-get install -y \
    nginx \
    reprepro \
    gnupg2 \
    curl \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Создание директорий для репозитория
RUN mkdir -p /var/www/repo/onec/conf && \
    mkdir -p /var/www/repo/onec/db && \
    mkdir -p /var/log/nginx

# Копирование конфигурационных файлов
COPY nginx.conf /etc/nginx/nginx.conf
COPY distributions /var/www/repo/onec/conf/distributions
COPY onec-repo-add.sh /var/www/repo/onec/onec-repo-add.sh
COPY start-http.sh /usr/local/bin/start-http.sh

# CRLF → LF (иначе shebang ломается при сборке из Windows: exec ... no such file)
RUN sed -i 's/\r$//' /usr/local/bin/start-http.sh /var/www/repo/onec/onec-repo-add.sh && \
    chmod +x /usr/local/bin/start-http.sh /var/www/repo/onec/onec-repo-add.sh

# Открытие портов
EXPOSE 80

# Запуск скрипта инициализации
CMD ["/usr/local/bin/start-http.sh"]
