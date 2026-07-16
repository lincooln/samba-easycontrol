#!/bin/bash

SHARES_CONF="/etc/samba/shares.conf"

if [ ! -f "$SHARES_CONF" ]; then
    exit 0
fi

current_name=""
current_path=""
current_guest="private"

while IFS= read -r line || [ -n "$line" ]; do
    # Убираем пробелы и символы возврата каретки
    line=$(echo "$line" | xargs)
    
    # Игнорируем абсолютно пустые строки
    if [ -z "$line" ]; then
        continue
    fi
    
    # Если нашли новую секцию
    if [[ "$line" =~ ^\[(.*)\]$ ]]; then
        # Выводим предыдущую, если её имя не пустое и это не служебный мусор
        if [ -n "$current_name" ] && [ -n "$current_path" ]; then
            echo "${current_name};${current_path};${current_guest}"
        fi
        current_name="${BASH_REMATCH[1]}"
        current_path=""
        current_guest="private"
    elif [[ "$line" =~ ^path\ *=\ *(.*)$ ]]; then
        current_path="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^guest\ ok\ *=\ *yes$ ]]; then
        current_guest="guest"
    fi
done < "$SHARES_CONF"

# Выводим самую последнюю секцию файла (если она валидна)
if [ -n "$current_name" ] && [ -n "$current_path" ]; then
    echo "${current_name};${current_path};${current_guest}"
fi
