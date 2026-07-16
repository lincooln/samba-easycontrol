#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Ошибка: Деинсталлятор необходимо запускать через sudo или от имени root!" >&2
    exit 1
fi

echo "=========================================="
echo " Начало полного удаления Samba EasyControl"
echo "=========================================="

TARGET_DIR="/usr/share/cockpit/samba-easycontrol"
SHARES_CONF="/etc/samba/shares.conf"
SUDOERS_FILE="/etc/sudoers.d/samba_easycontrol"

# 1. Принудительно размонтируем сетевые папки, чтобы не оставлять заблокированных путей
echo "Безопасное размонтирование активных CIFS-дисков..."
if [ -f /usr/bin/findmnt ] || [ -f /bin/findmnt ]; then
    findmnt -t cifs -n -o TARGET | while read -r target; do
        umount -l "$target" 2>/dev/null
    done
fi

# 2. Возвращаем конфигурацию Samba к исходному виду
echo "Восстановление конфигурации Samba..."
if [ -f /etc/samba/smb.conf.bak.samba_easycontrol ]; then
    # Возвращаем чистый бэкап, сделанный при установке
    mv -f /etc/samba/smb.conf.bak.samba_easycontrol /etc/samba/smb.conf
else
    # Если бэкап потерялся, аккуратно вырезаем наши маркеры
    sed -i '/include = \/etc\/samba\/shares.conf/d' /etc/samba/smb.conf
    sed -i '/# Подключение сетевых папок из плагина Cockpit/d' /etc/samba/smb.conf
fi

# Удаляем файл расшаренных сервером папок
[ -f "$SHARES_CONF" ] && rm -f "$SHARES_CONF"

# Стираем скрытые временные файлы credentials
rm -f /etc/samba/cred_* 2>/dev/null

# 3. Стираем правила повышенных привилегий sudoers
echo "Удаление правил беспарольного доступа sudoers..."
[ -f "$SUDOERS_FILE" ] && rm -f "$SUDOERS_FILE"

# 4. Полностью удаляем директорию плагина из Cockpit
echo "Удаление файлов веб-интерфейса..."
[ -d "$TARGET_DIR" ] && rm -rf "$TARGET_DIR"

# 5. Применяем чистую конфигурацию к системе
echo "Обновление состояния служб..."
killall cockpit-bridge 2>/dev/null
systemctl restart cockpit 2>/dev/null

if systemctl is-active --quiet smbd; then
    systemctl restart smbd
elif systemctl is-active --quiet smb; then
    systemctl restart smb
fi

echo "=========================================="
echo " Проект полностью удален из системы! 🪣"
echo "=========================================="
