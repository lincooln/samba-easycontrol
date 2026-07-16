#!/bin/bash

SHARE_NAME="$1"
SHARES_CONF="/etc/samba/shares.conf"

if [ -z "$SHARE_NAME" ]; then
    echo "Ошибка: Не указано имя сетевой шары для удаления!" >&2
    exit 1
fi

if [ ! -f "$SHARES_CONF" ]; then
    echo "Ошибка: Конфигурационный файл $SHARES_CONF не найден!" >&2
    exit 1
fi

echo "Закрываю сетевой доступ к шаре: [$SHARE_NAME]..."

# Создаем временный пустой файл для перезаписи
TMP_FILE=$(mktemp)

# ИСПРАВЛЕННАЯ ЛОГИКА AWK: 
# Как только встречаем ЛЮБУЮ строку, начинающуюся с [
# мы сначала проверяем, совпадает ли она с нашей целью.
# Если это наша цель — включаем пропуск (skip=1).
# Если это ЛЮБАЯ ДРУГАЯ секция — принудительно выключаем пропуск (skip=0).
awk -v target="[$SHARE_NAME]" '
    /^\[/ {
        if ($0 == target) {
            skip = 1;
            next;
        } else {
            skip = 0;
        }
    }
    !skip { print $0 }
' "$SHARES_CONF" > "$TMP_FILE"

# Безопасно накатываем измененную конфигурацию поверх старой через sudo tee
cat "$TMP_FILE" | sudo tee "$SHARES_CONF" > /dev/null

# Удаляем временный файл
rm -f "$TMP_FILE"

# Перезагружаем Samba для применения изменений на лету
if systemctl is-active --quiet smbd; then
    sudo systemctl reload smbd
elif systemctl is-active --quiet smb; then
    sudo systemctl reload smb
fi

echo "Успешно: Сетевой доступ к [$SHARE_NAME] закрыт!"
exit 0
