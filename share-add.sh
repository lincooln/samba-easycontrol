#!/bin/bash

SHARE_NAME="$1"
LOCAL_PATH="$2"
ACCESS_TYPE="$3"

SHARES_CONF="/etc/samba/shares.conf"

# 1. Валидация входных данных
if [ -z "$SHARE_NAME" ] || [ -z "$LOCAL_PATH" ]; then
    echo "Ошибка: Имя шары и локальный путь обязательны!" >&2
    exit 1
fi

# Очищаем имя шары от спецсимволов и пробелов для безопасности конфигурации
SHARE_NAME=$(echo "$SHARE_NAME" | tr -cd '[:alnum:]_-')

# 2. Проверяем/создаем локальную папку
if [ ! -d "$LOCAL_PATH" ]; then
    sudo mkdir -p "$LOCAL_PATH"
    # Даем папке полные права, чтобы Samba могла корректно работать с ней
    sudo chmod 777 "$LOCAL_PATH"
fi

# 3. Проверяем, нет ли уже шары с таким именем в shares.conf
if [ -f "$SHARES_CONF" ] && grep -q "^\[$SHARE_NAME\]" "$SHARES_CONF"; then
    echo "Ошибка: Сетевая шара с именем [$SHARE_NAME] уже существует!" >&2
    exit 1
fi

# 4. Формируем текстовый блок конфигурации Samba
BLOCK="\n[$SHARE_NAME]\n"
BLOCK="$BLOCK    path = $LOCAL_PATH\n"
BLOCK="$BLOCK    browseable = yes\n"

if [ "$ACCESS_TYPE" = "guest" ]; then
    BLOCK="$BLOCK    writable = yes\n"
    BLOCK="$BLOCK    guest ok = yes\n"
    BLOCK="$BLOCK    force user = nobody\n"
else
    BLOCK="$BLOCK    writable = yes\n"
    BLOCK="$BLOCK    guest ok = no\n"
fi

# 5. Записываем блок в файл конфигурации через sudo tee
echo -e "$BLOCK" | sudo tee -a "$SHARES_CONF" > /dev/null

# 6. Перезапускаем или перезагружаем службу Samba для применения настроек
if systemctl is-active --quiet smbd; then
    sudo systemctl reload smbd
elif systemctl is-active --quiet smb; then
    sudo systemctl reload smb
fi

echo "Успешно: Папка [$SHARE_NAME] открыта для сетевого доступа!"
exit 0
