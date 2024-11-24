#!/bin/bash

# Функция для проверки наличия утилиты
check_utility() {
    command -v "$1" &> /dev/null
    if [ $? -ne 0 ]; then
        echo "Утилита '$1' не найдена."
        return 1
    fi
    echo "Утилита '$1' найдена."
    return 0
}

# Функция для установки утилит
install_utilities() {
    echo "Установка необходимых утилит..."
    if [ -x "$(command -v apt)" ]; then
        sudo apt update && sudo apt install -y iputils-ping iproute2 curl
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y iputils curl
    elif [ -x "$(command -v dnf)" ]; then
        sudo dnf install -y iputils curl
    else
        echo "Установщик пакетов не поддерживается. Пожалуйста, установите утилиты вручную."
        exit 1
    fi
}

# Функция для проверки соединения с интернетом
check_internet() {
    if ping -c 1 8.8.8.8 &> /dev/null; then
        echo "Соединение с интернетом установлено."
        return 0
    else
        echo "Нет соединения с интернетом."
        return 1
    fi
}

# Функция для получения информации о соединении
get_connection_info() {
    echo "Информация о соединении:"
    echo "---------------------------------"
    
    # Вывод информации о сетевых интерфейсах
    echo "Сетевые интерфейсы:"
    ip addr show

    # Вывод информации о маршрутах
    echo "Маршруты:"
    ip route show

    # Вывод информации о DNS
    echo "DNS-серверы:"
    cat /etc/resolv.conf

    # Вывод информации о текущем IP-адресе
    echo "Ваш IP-адрес:"
    curl -s ifconfig.me
}

# Основной блок скрипта
# Проверка наличия необходимых утилит
utilities=("ping" "ip" "curl")
for utility in "${utilities[@]}"; do
    check_utility "$utility" || install_utilities
done

# Теперь проверим соединение с интернетом
if check_internet; then
    get_connection_info
else
    echo "Попробуйте проверить соединение позже."
fi

