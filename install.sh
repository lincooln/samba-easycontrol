#!/bin/bash

# Проверяем, запущен ли скрипт от root
if [ "$EUID" -ne 0 ]; then
    echo "Ошибка: Этот скрипт необходимо запускать через sudo или от имени root!" >&2
    exit 1
fi

echo "=========================================="
echo " Начало установки Samba EasyControl для Cockpit"
echo "=========================================="

# 1. Определяем дистрибутив Linux
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_FAMILY=$ID_LIKE
    [ -z "$OS_FAMILY" ] && OS_FAMILY=$ID
else
    echo "Ошибка: Не удалось определить тип операционной системы!" >&2
    exit 1
fi

echo "Обнаружена ОС: $NAME ($OS_FAMILY)"

# 2. Устанавливаем системные пакеты
echo "Проверка и установка необходимых зависимостей..."
case "$OS_FAMILY" in
    *debian*|*ubuntu*)
        apt-get update && apt-get install -y samba cifs-utils smbclient cockpit coreutils awk grep
        ;;
    *rhel*|*fedora*|*centos*)
        dnf install -y samba cifs-utils samba-client cockpit coreutils gawk grep
        ;;
    *altlinux*)
        apt-get update && apt-get install -y samba-server cifs-utils samba-client cockpit coreutils gawk grep
        ;;
    *)
        echo "Предупреждение: Неизвестный дистрибутив. Убедитесь, что samba, cifs-utils, smbclient и cockpit установлены."
        ;;
esac

# 3. Вычисляем имя пользователя, который запустил инсталлятор через sudo, 
# чтобы прописать права именно для его веб-сессии в Cockpit
REAL_USER=${SUDO_USER:-$(whoami)}
if [ "$REAL_USER" = "root" ]; then
    # Если скрипт запущен напрямую из-под root (без sudo), берем первого обычного пользователя (UID >= 1000)
    REAL_USER=$(awk -F: '$3>=1000 && $3<60000 {print $1; exit}' /etc/passwd)
fi

if [ -z "$REAL_USER" ]; then
    echo "Ошибка: Не удалось определить целевого пользователя для интеграции правил sudoers!" >&2
    exit 1
fi

echo "Настройка беспарольного доступа к утилитам для пользователя: $REAL_USER"

# 4. Создаем изолированный файл правил sudoers
SUDOERS_FILE="/etc/sudoers.d/samba_easycontrol"
echo "${REAL_USER} ALL=(ALL) NOPASSWD: /usr/share/cockpit/samba-easycontrol/mount-helper.sh, /usr/share/cockpit/samba-easycontrol/umount-helper.sh, /usr/share/cockpit/samba-easycontrol/scan-helper.sh, /usr/share/cockpit/samba-easycontrol/share-add.sh, /usr/share/cockpit/samba-easycontrol/share-list.sh, /usr/share/cockpit/samba-easycontrol/share-remove.sh, /usr/bin/mount, /bin/mount, /usr/bin/umount, /bin/umount, /usr/bin/mkdir, /bin/mkdir, /usr/bin/chown, /bin/chown, /usr/bin/tee, /usr/bin/rm, /bin/rm, /usr/bin/findmnt, /bin/findmnt, /usr/bin/systemctl, /bin/systemctl" > "$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"

# 5. Интегрируем плагин в основной конфигурационный файл Samba
echo "Настройка конфигурации Samba..."
sudo touch /etc/samba/shares.conf
sudo chmod 644 /etc/samba/shares.conf

if [ -f /etc/samba/smb.conf ]; then
    if ! grep -q "include = /etc/samba/shares.conf" /etc/samba/smb.conf; then
        # Делаем резервную копию на всякий случай
        cp /etc/samba/smb.conf /etc/samba/smb.conf.bak.samba_easycontrol
        echo -e "\n# Подключение сетевых папок из плагина Cockpit\ninclude = /etc/samba/shares.conf" >> /etc/samba/smb.conf
        echo "Строка include успешно интегрирована в /etc/samba/smb.conf."
    else
        echo "Строка include уже присутствует в основном smb.conf."
    fi
else
    echo "Предупреждение: /etc/samba/smb.conf не найден. Создаю базовый рабочий файл..."
    echo -e "[global]\n    workgroup = WORKGROUP\n    server string = Samba Server\n    security = user\n    map to guest = Bad User\n\ninclude = /etc/samba/shares.conf" > /etc/samba/smb.conf
fi

# 6. Копируем файлы проекта в целевую директорию Cockpit
echo "Развертывание веб-интерфейса плагина..."
TARGET_DIR="/usr/share/cockpit/samba-easycontrol"
mkdir -p "$TARGET_DIR"

# Копируем всё из текущей папки, откуда запущен инсталлятор
cp -f manifest.json index.html index.css index.js mount-helper.sh umount-helper.sh scan-helper.sh share-add.sh share-list.sh share-remove.sh "$TARGET_DIR/" 2>/dev/null

# Также закидываем копию деинсталлятора, чтобы утилита удаления всегда лежала внутри проекта
cp -f uninstall.sh "$TARGET_DIR/" 2>/dev/null

# Выставляем правильные права на исполнение для всех бэкенд-скриптов
chmod +x "$TARGET_DIR"/*.sh

# 7. Применяем настройки и сбрасываем системные кэши
echo "Обновление системных демонов..."
systemctl restart cockpit 2>/dev/null
killall cockpit-bridge 2>/dev/null

if systemctl is-active --quiet smbd; then
    systemctl reload smbd
elif systemctl is-active --quiet smb; then
    systemctl reload smb
fi

echo "=========================================="
echo " Установка успешно завершена! 🎉"
echo " Обновите страницу Cockpit и откройте инструмент 'Samba'."
echo "=========================================="
