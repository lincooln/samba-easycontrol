#!/bin/bash

TARGET_PATH="$1"

if [ -z "$TARGET_PATH" ]; then
    echo "Ошибка: Не указана точка монтирования!" >&2
    exit 1
fi

# Автоматически находим абсолютные пути к системным утилитам
FINDMNT_BIN=$(which findmnt)
[ -z "$FINDMNT_BIN" ] && FINDMNT_BIN="/bin/findmnt"

UMOUNT_BIN=$(which umount)
[ -z "$UMOUNT_BIN" ] && UMOUNT_BIN="/bin/umount"

RM_BIN=$(which rm)
[ -z "$RM_BIN" ] && RM_BIN="/bin/rm"

# 1. Находим сетевой путь шары через sudo findmnt
SHARE_PATH=$(sudo $FINDMNT_BIN -n -o SOURCE "$TARGET_PATH")

# 2. Выполняем ленивое размонтирование через sudo
sudo $UMOUNT_BIN -l "$TARGET_PATH"
UMOUNT_STATUS=$?

if [ $UMOUNT_STATUS -eq 0 ]; then
    echo "Успешно размонтировано: $TARGET_PATH"
    
    # 3. Если сетевой путь был найден, вычисляем хэш и безопасно удаляем credentials через sudo rm
    if [ -n "$SHARE_PATH" ]; then
        CREDS_NAME=$(echo -n "$SHARE_PATH" | md5sum 2>/dev/null | awk '{print $1}')
        [ -z "$CREDS_NAME" ] && CREDS_NAME=$(echo -n "$SHARE_PATH" | tr -cd '[:alnum:]')
        
        CREDS_FILE="/etc/samba/cred_$CREDS_NAME"
        if [ -f "$CREDS_FILE" ]; then
            sudo $RM_BIN -f "$CREDS_FILE"
        fi
    fi
    exit 0
else
    echo "Ошибка при размонтировании $TARGET_PATH" >&2
    exit 1
fi
