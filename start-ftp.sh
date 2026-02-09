#!/bin/bash
set -e

echo "Starting FTP repository initialization..."

# Создание директорий если их нет
mkdir -p /srv/ftp/onec/conf
mkdir -p /srv/ftp/onec/db
mkdir -p /srv/ftp/onec/pool
mkdir -p /srv/ftp/onec/dists

# Проверка наличия конфигурационного файла distributions
if [ ! -f /srv/ftp/onec/conf/distributions ]; then
    echo "Error: distributions file not found!"
    exit 1
fi

# Генерация GPG ключа если его нет
if [ ! -f /root/.gnupg/pubring.kbx ] && [ ! -f /root/.gnupg/pubring.gpg ]; then
    echo "Generating GPG key..."
    export GPG_TTY=$(tty)
    
    # Создание batch файла для генерации ключа
    cat > /tmp/gpg-batch <<EOF
%no-protection
Key-Type: RSA
Key-Length: 2048
Name-Real: Repository Admin
Name-Email: repo@localhost
Expire-Date: 0
%commit
EOF
    
    gpg --batch --gen-key /tmp/gpg-batch
    rm /tmp/gpg-batch
    
    echo "GPG key generated successfully"
fi

# Экспорт публичного ключа
if [ ! -f /srv/ftp/onec/repo_gpg.key ]; then
    echo "Exporting GPG public key..."
    # Попытка экспорта по email
    KEY_ID=$(gpg --list-keys --keyid-format LONG 2>/dev/null | grep -E "^pub" | head -1 | awk '{print $2}' | cut -d'/' -f2)
    if [ -n "$KEY_ID" ]; then
        gpg --armor --output /srv/ftp/onec/repo_gpg.key --export "$KEY_ID" 2>/dev/null || \
        gpg --armor --output /srv/ftp/onec/repo_gpg.key --export repo@localhost 2>/dev/null
    else
        echo "Warning: No GPG key found for export"
    fi
fi

# Инициализация репозитория если его еще нет
if [ ! -f /srv/ftp/onec/db/version ] && [ ! -d /srv/ftp/onec/dists ]; then
    echo "Initializing repository structure..."
    reprepro -b /srv/ftp/onec export 2>&1 || echo "Repository structure initialized"
fi

# Добавление пакетов из /tmp/distr если они есть
if [ -d /tmp/distr ] && [ "$(ls -A /tmp/distr/*.deb 2>/dev/null)" ]; then
    echo "Adding packages from /tmp/distr..."
    for deb_file in /tmp/distr/*.deb; do
        if [ -f "$deb_file" ]; then
            echo "Adding package: $(basename $deb_file)"
            reprepro -b /srv/ftp/onec includedeb 8.5.1.1150_x86-64 "$deb_file" 2>&1 || echo "Package $(basename $deb_file) may already exist or error occurred"
        fi
    done
fi

# Генерация финального скрипта onec-repo-add.sh с встроенным GPG ключом
if [ -f /srv/ftp/onec/repo_gpg.key ] && [ -f /srv/ftp/onec/onec-repo-add.sh ]; then
    echo "Generating onec-repo-add.sh with embedded GPG key..."
    
    # Используем Python для надежной замены ключа
    python3 << 'PYTHON_SCRIPT' > /tmp/onec-repo-add-final.sh
import sys
import re

# Читаем оригинальный скрипт
with open('/srv/ftp/onec/onec-repo-add.sh', 'r') as f:
    script_content = f.read()

# Читаем GPG ключ (он уже содержит маркеры BEGIN и END)
with open('/srv/ftp/onec/repo_gpg.key', 'r') as f:
    gpg_key_full = f.read().strip()

# Заменяем плейсхолдер GPG ключа на реальный ключ
# Ищем блок после комментария "# GPG key will be inserted here" и заменяем весь блок включая маркеры
placeholder_pattern = r'# GPG key will be inserted here.*?\n-----BEGIN PGP PUBLIC KEY BLOCK-----\n.*?\n-----END PGP PUBLIC KEY BLOCK-----'
result = re.sub(placeholder_pattern, gpg_key_full, script_content, flags=re.DOTALL)

# Если замена не произошла, пробуем найти блок без комментария (но не переменные KEY_START/KEY_END)
if result == script_content:
    # Ищем блок, который находится после строки с комментарием (не в определении переменных)
    # Используем более точный паттерн - блок после строки 98 (после echo "apt install")
    pattern = r'(echo "  apt install.*?\n\n)(# GPG key will be inserted here.*?\n)?-----BEGIN PGP PUBLIC KEY BLOCK-----\n.*?\n-----END PGP PUBLIC KEY BLOCK-----'
    match = re.search(pattern, script_content, flags=re.DOTALL)
    if match:
        # Заменяем только блок с маркерами, сохраняя текст до него
        result = re.sub(r'-----BEGIN PGP PUBLIC KEY BLOCK-----\n.*?\n-----END PGP PUBLIC KEY BLOCK-----', gpg_key_full, script_content, flags=re.DOTALL, count=1)
    else:
        # Последняя попытка - заменяем последний блок с маркерами (не первый, который в переменных)
        blocks = list(re.finditer(r'-----BEGIN PGP PUBLIC KEY BLOCK-----.*?-----END PGP PUBLIC KEY BLOCK-----', script_content, flags=re.DOTALL))
        if len(blocks) > 1:
            # Заменяем последний блок
            last_block = blocks[-1]
            result = script_content[:last_block.start()] + gpg_key_full + script_content[last_block.end():]

sys.stdout.write(result)
PYTHON_SCRIPT
    
    mv /tmp/onec-repo-add-final.sh /srv/ftp/onec/onec-repo-add.sh
    chmod +x /srv/ftp/onec/onec-repo-add.sh
    chmod 755 /srv/ftp/onec/onec-repo-add.sh
    echo "onec-repo-add.sh generated with embedded GPG key"
fi

# Установка прав доступа
chown -R ftp:ftp /srv/ftp 2>/dev/null || chmod -R 755 /srv/ftp
chmod -R 755 /srv/ftp/onec
# Для анонимного FTP корневая директория должна быть только для чтения
chmod 555 /srv/ftp

echo "Repository initialization completed"
echo "GPG public key location: /srv/ftp/onec/repo_gpg.key"
echo "Repository URL: ftp://edu-ks-beringpro.1cit.com/onec/8.5.1.1150_x86-64"

# Настройка pasv_address если указана переменная окружения
if [ -n "$PASV_ADDRESS" ]; then
    echo "Setting PASV_ADDRESS to $PASV_ADDRESS"
    sed -i "s|^pasv_address=.*|pasv_address=$PASV_ADDRESS|" /etc/vsftpd.conf
fi

# Запуск vsftpd в foreground режиме
echo "Starting vsftpd..."
exec vsftpd /etc/vsftpd.conf
