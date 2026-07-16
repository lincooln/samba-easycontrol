#!/bin/bash

SHARE_PATH="$1"
LOCAL_PATH="$2"
SMB_USER="$3"
SMB_PASS="$4"
CURRENT_UID="$5"
CURRENT_GID="$6"

# Отладочная запись: проверяем, что пришло в скрипт из Cockpit
echo "=== ЗАПУСК СКРИПТА ===" > /tmp/samba_debug.log
echo "Путь шары: '$SHARE_PATH'" >> /tmp/samba_debug.log
echo "Точка монтирования: '$LOCAL_PATH'" >> /tmp/samba_debug.log
echo "Пользователь: '$SMB_USER'" >> /tmp/samba_debug.log
echo "UID: '$CURRENT_UID', GID: '$CURRENT_GID'" >> /tmp/samba_debug.log

# Безопасная проверка аргументов без генерации кода 2
if [[ -z "$SHARE_PATH" ]] || [[ -z "$LOCAL_PATH" ]]; then
    echo "Ошибка: Сетевой путь и точка монтирования обязательны!" >&2
    exit 1
fi

if [[ ! -d "$LOCAL_PATH" ]]; then
    sudo mkdir -p "$LOCAL_PATH"
    sudo chown "${CURRENT_UID}:${CURRENT_GID}" "$LOCAL_PATH"
fi

MOUNT_OPTS="uid=${CURRENT_UID},gid=${CURRENT_GID}"

if [[ -n "$SMB_USER" ]]; then
    CREDS_NAME=$(echo -n "$SHARE_PATH" | md5sum 2>/dev/null | awk '{print $1}')
    [[ -z "$CREDS_NAME" ]] && CREDS_NAME=$(echo -n "$SHARE_PATH" | tr -cd '[:alnum:]')
    
    CREDS_FILE="/etc/samba/cred_$CREDS_NAME"
    
    echo "username=$SMB_USER" | sudo tee "$CREDS_FILE" > /dev/null
    echo "password=$SMB_PASS" | sudo tee -a "$CREDS_FILE" > /dev/null
    sudo chmod 600 "$CREDS_FILE"
    
    MOUNT_OPTS="$MOUNT_OPTS,credentials=$CREDS_FILE"
else
    MOUNT_OPTS="$MOUNT_OPTS,guest,sec=none"
fi

MOUNT_BIN=$(which mount)
[[ -z "$MOUNT_BIN" ]] && MOUNT_BIN="/bin/mount"

echo "Выполняю команду: sudo $MOUNT_BIN -t cifs -o $MOUNT_OPTS $SHARE_PATH $LOCAL_PATH" >> /tmp/samba_debug.log
MOUNT_OUTPUT=$(sudo $MOUNT_BIN -t cifs -o "$MOUNT_OPTS" "$SHARE_PATH" "$LOCAL_PATH" 2>&1)
MOUNT_STATUS=$?

echo "Статус команды mount: $MOUNT_STATUS" >> /tmp/samba_debug.log
echo "Вывод команды mount: $MOUNT_OUTPUT" >> /tmp/samba_debug.log

if [[ $MOUNT_STATUS -eq 0 ]]; then
    echo "Успешно примонтировано!" >> /tmp/samba_debug.log
    exit 0
else
    echo "Системная ошибка: $MOUNT_OUTPUT" >&2
    [[ -f "$CREDS_FILE" ]] && sudo rm -f "$CREDS_FILE"
    exit 1
fi
