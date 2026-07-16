#!/bin/bash

# Находим основной локальный IP-адрес сервера (исключая loopback и docker)
LOCAL_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}')
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP=$(hostname -I | awk '{print $1}')
fi

if [ -z "$LOCAL_IP" ]; then
    echo "Ошибка: Не удалось определить локальный IP-адрес!" >&2
    exit 1
fi

# Вычисляем маску подсети (берем первые три октета, например: 192.168.3.)
SUBNET=$(echo "$LOCAL_IP" | cut -d. -f1-3)

echo "Сканирую подсеть ${SUBNET}.0/24 на наличие SMB-устройств..."

# Запускаем параллельный перебор адресов от 1 до 254 для максимальной скорости (в фоне)
for i in {1..254}; do
    (
        TARGET_IP="${SUBNET}.${i}"
        
        # Проверяем доступность порта 445 (Samba/CIFS) с таймаутом в 1 секунду
        if timeout 1 bash -c "cat < /dev/null > /dev/tcp/${TARGET_IP}/445" 2>/dev/null; then
            # Пытаемся узнать сетевое имя компьютера через nmblookup (если NetBIOS все же отвечает)
            NAME=$(nmblookup -A "$TARGET_IP" 2>/dev/null | grep -i '<00>' | grep -v -i 'GROUP' | head -n1 | awk '{print $1}')
            
            if [ -z "$NAME" ]; then
                NAME="Сетевое устройство"
            fi
            
            # Выводим результат в формате: IP;ИМЯ
            echo "${TARGET_IP};${NAME}"
        fi
    ) &
done

# Ждем завершения всех фоновых потоков сканирования
wait
