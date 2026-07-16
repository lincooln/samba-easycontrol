#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Ошибка: Этот скрипт необходимо запускать через sudo или от имени root!" >&2
    exit 1
fi

echo "=========================================="
echo " Начало установки Samba EasyControl для Cockpit"
echo "=========================================="

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_FAMILY=$ID_LIKE
    [ -z "$OS_FAMILY" ] && OS_FAMILY=$ID
else
    echo "Ошибка: Не удалось определить тип операционной системы!" >&2
    exit 1
fi

echo "Обнаружена ОС: $NAME ($OS_FAMILY)"

echo "Проверка и установка необходимых зависимостей..."
case "$OS_FAMILY" in
    *debian*|*ubuntu*)
        apt-get update && apt-get install -y samba cifs-utils smbclient cockpit coreutils grep
        ;;
    *rhel*|*fedora*|*centos*)
        dnf install -y samba cifs-utils samba-client cockpit coreutils grep
        ;;
    *altlinux*)
        apt-get update && apt-get install -y samba-server cifs-utils samba-client cockpit coreutils grep
        ;;
    *)
        echo "Предупреждение: Неизвестный дистрибутив. Убедитесь, что зависимости установлены."
        ;;
esac

modprobe cifs 2>/dev/null

# Определение реального пользователя
REAL_USER=${SUDO_USER:-$(whoami)}
if [ "$REAL_USER" = "root" ]; then
    REAL_USER=$(awk -F: '$3>=1000 && $3<60000 {print $1; exit}' /etc/passwd)
fi

if [ -z "$REAL_USER" ]; then
    echo "Ошибка: Не удалось определить целевого пользователя для интеграции правил sudoers!" >&2
    exit 1
fi

# ДОБАВЛЕНО: Настройка групп и пользователя Samba для приватных шар
echo "Настройка сетевых групп и учетной записи Samba..."
# Создаем группу для сетевого доступа, если её нет
if ! getent group sambashare >/dev/null; then
    groupadd sambashare
fi
# Добавляем нашего пользователя в группу
usermod -aG sambashare "$REAL_USER"

# Проверяем, добавлен ли пользователь в базу Samba. Если нет — добавляем.
# (Изначально аккаунт создается отключенным, без пароля, пользователь сможет задать его командой 'sudo smbpasswd -a имя')
if ! pdbedit -L | grep -q "^${REAL_USER}:"; then
    (echo ""; echo "") | smbpasswd -s -a "$REAL_USER" >/dev/null 2>&1
    smbpasswd -e "$REAL_USER" >/dev/null 2>&1
    echo "Пользователь [$REAL_USER] импортирован в базу Samba."
fi

echo "Настройка беспарольного доступа к утилитам для пользователя: $REAL_USER"

SUDOERS_FILE="/etc/sudoers.d/samba_easycontrol"
echo "${REAL_USER} ALL=(ALL) NOPASSWD: /usr/share/cockpit/samba-easycontrol/mount-helper.sh, /usr/share/cockpit/samba-easycontrol/umount-helper.sh, /usr/share/cockpit/samba-easycontrol/scan-helper.sh, /usr/share/cockpit/samba-easycontrol/share-add.sh, /usr/share/cockpit/samba-easycontrol/share-list.sh, /usr/share/cockpit/samba-easycontrol/share-remove.sh, /usr/bin/mount, /bin/mount, /usr/bin/umount, /bin/umount, /usr/bin/mkdir, /bin/mkdir, /usr/bin/chown, /bin/chown, /usr/bin/tee, /usr/bin/rm, /bin/rm, /usr/bin/findmnt, /bin/findmnt, /usr/bin/systemctl, /bin/systemctl" > "$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"

echo "Настройка конфигурации Samba..."
sudo mkdir -p /etc/samba
sudo touch /etc/samba/shares.conf
sudo chmod 644 /etc/samba/shares.conf

if [ -f /etc/samba/smb.conf ]; then
    if ! grep -q "include = /etc/samba/shares.conf" /etc/samba/smb.conf; then
        cp /etc/samba/smb.conf /etc/samba/smb.conf.bak.samba_easycontrol
        echo -e "\n# Подключение сетевых папок из плагина Cockpit\ninclude = /etc/samba/shares.conf" >> /etc/samba/smb.conf
    fi
else
    echo -e "[global]\n    workgroup = WORKGROUP\n    server string = Samba Server\n    security = user\n    map to guest = Bad User\n\ninclude = /etc/samba/shares.conf" > /etc/samba/smb.conf
fi

echo "Развертывание веб-интерфейса плагина..."
TARGET_DIR="/usr/share/cockpit/samba-easycontrol"
mkdir -p "$TARGET_DIR"

# Если файлы лежат в текущей папке, копируем их
cp -f manifest.json index.html index.css index.js mount-helper.sh umount-helper.sh scan-helper.sh share-add.sh share-list.sh share-remove.sh "$TARGET_DIR/" 2>/dev/null
cp -f uninstall.sh "$TARGET_DIR/" 2>/dev/null
chmod +x "$TARGET_DIR"/*.sh

echo "Активация и запуск системных служб..."
systemctl daemon-reload
systemctl enable --now cockpit.socket 2>/dev/null
systemctl restart cockpit 2>/dev/null

killall cockpit-bridge cockpit-session 2>/dev/null

if systemctl list-unit-files | grep -q "smbd.service"; then
    SMB_SERVICE="smbd"
elif systemctl list-unit-files | grep -q "smb.service"; then
    SMB_SERVICE="smb"
fi

if [ -n "$SMB_SERVICE" ]; then
    systemctl enable "$SMB_SERVICE"
    systemctl restart "$SMB_SERVICE"
fi

echo "=========================================="
echo " Установка успешно завершена! 🎉"
echo " КРИТИЧЕСКИ ВАЖНО: Выйдите из Cockpit (Log Out) и войдите"
echo " заново, чтобы система применила новые права sudoers и групп!"
echo "=========================================="
