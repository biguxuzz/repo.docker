#!/bin/bash
set -e

echo "Starting HTTP repository initialization..."

# Создание директорий если их нет
mkdir -p /var/www/repo/onec/conf
mkdir -p /var/www/repo/onec/db
mkdir -p /var/www/repo/onec/pool
mkdir -p /var/www/repo/onec/dists

# Проверка наличия конфигурационного файла distributions
if [ ! -f /var/www/repo/onec/conf/distributions ]; then
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
if [ ! -f /var/www/repo/onec/repo_gpg.key ]; then
    echo "Exporting GPG public key..."
    # Попытка экспорта по email
    KEY_ID=$(gpg --list-keys --keyid-format LONG 2>/dev/null | grep -E "^pub" | head -1 | awk '{print $2}' | cut -d'/' -f2)
    if [ -n "$KEY_ID" ]; then
        gpg --armor --output /var/www/repo/onec/repo_gpg.key --export "$KEY_ID" 2>/dev/null || \
        gpg --armor --output /var/www/repo/onec/repo_gpg.key --export repo@localhost 2>/dev/null
    else
        echo "Warning: No GPG key found for export"
    fi
fi

# Инициализация репозитория если его еще нет
if [ ! -f /var/www/repo/onec/db/version ] && [ ! -d /var/www/repo/onec/dists ]; then
    echo "Initializing repository structure..."
    reprepro -b /var/www/repo/onec export 2>&1 || echo "Repository structure initialized"
fi

# Добавление пакетов из /tmp/distr если они есть
if [ -d /tmp/distr ] && [ "$(ls -A /tmp/distr/*.deb 2>/dev/null)" ]; then
    echo "Adding packages from /tmp/distr..."
    for deb_file in /tmp/distr/*.deb; do
        if [ -f "$deb_file" ]; then
            echo "Adding package: $(basename $deb_file)"
            reprepro -b /var/www/repo/onec includedeb 8.5.1.1150_x86-64 "$deb_file" 2>&1 || echo "Package $(basename $deb_file) may already exist or error occurred"
        fi
    done
fi

# Генерация финального скрипта onec-repo-add.sh с встроенным GPG ключом
if [ -f /var/www/repo/onec/repo_gpg.key ] && [ -f /var/www/repo/onec/onec-repo-add.sh ]; then
    echo "Generating onec-repo-add.sh with embedded GPG key..."
    
    # Используем Python для надежной замены ключа
    python3 << 'PYTHON_SCRIPT' > /tmp/onec-repo-add-final.sh
import sys
import re

# Читаем оригинальный скрипт
with open('/var/www/repo/onec/onec-repo-add.sh', 'r') as f:
    script_content = f.read()

# Читаем GPG ключ (он уже содержит маркеры BEGIN и END)
with open('/var/www/repo/onec/repo_gpg.key', 'r') as f:
    gpg_key_full = f.read().strip()

# Заменяем плейсхолдер GPG ключа на реальный ключ
# Ищем блок между BEGIN и END маркерами (не в определении переменных)
placeholder_pattern = r'-----BEGIN PGP PUBLIC KEY BLOCK-----\n.*?\(Key will be inserted here automatically\)\n.*?\n-----END PGP PUBLIC KEY BLOCK-----'
result = re.sub(placeholder_pattern, gpg_key_full, script_content, flags=re.DOTALL)

# Если замена не произошла, пробуем найти любой блок с плейсхолдером
if result == script_content:
    # Ищем блок после строки с комментарием
    pattern = r'(-----BEGIN PGP PUBLIC KEY BLOCK-----\n)(.*?\(Key will be inserted here.*?\n)(.*?\n-----END PGP PUBLIC KEY BLOCK-----)'
    result = re.sub(pattern, gpg_key_full, script_content, flags=re.DOTALL)

# Если все еще не заменилось, заменяем последний блок с маркерами
if result == script_content:
    blocks = list(re.finditer(r'-----BEGIN PGP PUBLIC KEY BLOCK-----.*?-----END PGP PUBLIC KEY BLOCK-----', script_content, flags=re.DOTALL))
    if len(blocks) > 0:
        # Заменяем последний блок (который должен быть плейсхолдером)
        last_block = blocks[-1]
        result = script_content[:last_block.start()] + gpg_key_full + script_content[last_block.end():]

sys.stdout.write(result)
PYTHON_SCRIPT
    
    mv /tmp/onec-repo-add-final.sh /var/www/repo/onec/onec-repo-add.sh
    chmod +x /var/www/repo/onec/onec-repo-add.sh
    chmod 755 /var/www/repo/onec/onec-repo-add.sh
    echo "onec-repo-add.sh generated with embedded GPG key"
fi

# Установка прав доступа для nginx
chown -R www-data:www-data /var/www/repo
chmod -R 755 /var/www/repo/onec

echo "Repository initialization completed"
echo "GPG public key location: /var/www/repo/onec/repo_gpg.key"
echo "Repository URL: http://edu-ks-beringpro.1cit.com/onec/8.5.1.1150_x86-64"

# Запуск nginx в foreground режиме
echo "Starting nginx..."
exec nginx -g "daemon off;"
