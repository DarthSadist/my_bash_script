#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Логирование
LOG_FILE="/tmp/network_check.log"

# Функция логирования
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$LOG_FILE"
}

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
    local servers=("8.8.8.8" "1.1.1.1" "208.67.222.222")
    local success=false
    
    echo -e "${YELLOW}Проверка интернет-соединения...${NC}"
    log_message "Начало проверки интернет-соединения"
    
    for server in "${servers[@]}"; do
        if ping -c 3 "$server" &> /dev/null; then
            echo -e "${GREEN}Соединение с $server установлено.${NC}"
            log_message "Успешное соединение с $server"
            success=true
            break
        else
            echo -e "${RED}Нет соединения с $server.${NC}"
            log_message "Ошибка соединения с $server"
        fi
    done
    
    if [ "$success" = true ]; then
        return 0
    else
        return 1
    fi
}

# Функция для проверки качества соединения
check_connection_quality() {
    local target="8.8.8.8"
    echo -e "${YELLOW}Проверка качества соединения...${NC}"
    log_message "Начало проверки качества соединения"
    
    # Проверка задержки и потери пакетов
    echo -e "${GREEN}Тестирование задержки и потери пакетов...${NC}"
    
    # Сохраняем результат пинга во временную переменную
    local ping_result=$(ping -c 10 "$target")
    
    # Анализируем потери пакетов
    local packet_loss=$(echo "$ping_result" | grep "packet loss" | awk '{print $6}')
    echo -e "Потери пакетов: ${YELLOW}$packet_loss${NC}"
    
    # Анализируем задержки
    local delays=$(echo "$ping_result" | grep "min/avg/max/mdev" | \
        awk -F "=" '{print $2}' | \
        awk -F "/" '{printf "Минимальная задержка: %.1f ms\nСредняя задержка: %.1f ms\nМаксимальная задержка: %.1f ms\nСтандартное отклонение: %.1f ms", $1, $2, $3, $4}')
    echo -e "$delays" | sed "s/^/\t/"

    # Проверка скорости интернета
    echo -e "\n${GREEN}Проверка скорости интернета...${NC}"
    
    # Функция для тестирования скорости через curl
    test_speed_curl() {
        # Массив тестовых файлов разного размера
        declare -A test_files=(
            ["small"]="https://raw.githubusercontent.com/torvalds/linux/master/COPYING"
            ["medium"]="http://mirror.yandex.ru/ubuntu/dists/jammy/main/binary-amd64/Packages.gz"
            ["large"]="http://mirror.yandex.ru/ubuntu/dists/jammy/main/binary-amd64/Packages"
        )
        
        local max_speed=0
        local successful_test=false
        local test_duration=5  # Длительность теста в секундах
        
        echo -e "${YELLOW}Тестирование скорости загрузки...${NC}"
        
        # Функция для форматирования размера
        format_size() {
            local bytes=$1
            if [ -z "$bytes" ] || [ "$bytes" -eq 0 ]; then
                echo "0B"
                return
            fi
            if [ "$bytes" -lt 1024 ]; then
                echo "${bytes}B"
            elif [ "$bytes" -lt 1048576 ]; then
                LC_NUMERIC=C printf "%.1fKB" "$(echo "scale=1; $bytes/1024" | bc)"
            else
                LC_NUMERIC=C printf "%.1fMB" "$(echo "scale=1; $bytes/1048576" | bc)"
            fi
        }
        
        # Функция для форматирования времени
        format_time() {
            LC_NUMERIC=C printf "%.1f" "$1"
        }
        
        # Функция для форматирования скорости
        format_speed() {
            local speed=$1
            if [ -z "$speed" ] || [ "$(echo "$speed <= 0" | bc -l)" -eq 1 ]; then
                echo "0.00"
                return
            fi
            LC_NUMERIC=C printf "%.2f" "$speed"
        }
        
        # Тестируем каждый файл
        for size in "small" "medium" "large"; do
            local url="${test_files[$size]}"
            local server=$(echo "$url" | cut -d'/' -f3)
            
            echo -e "\nТестирование через ${GREEN}$server${NC} (файл: $size)"
            
            # Сначала получаем размер файла
            local file_size=$(curl -sI "$url" | grep -i content-length | awk '{print $2}' | tr -d '\r')
            if [ -n "$file_size" ]; then
                echo -e "Размер файла: $(format_size "$file_size")"
            fi
            
            # Измеряем скорость загрузки
            local curl_output=$(curl -o /dev/null "$url" \
                              --max-time $test_duration \
                              -w "time_total=%{time_total}\nsize_download=%{size_download}\nspeed_download=%{speed_download}" \
                              -s -L 2>/dev/null)
            
            if [ $? -eq 0 ] && [ -n "$curl_output" ]; then
                local time_total=$(echo "$curl_output" | grep time_total | cut -d= -f2)
                local size_download=$(echo "$curl_output" | grep size_download | cut -d= -f2)
                local speed_download=$(echo "$curl_output" | grep speed_download | cut -d= -f2)
                
                # Конвертируем скорость из байт/сек в МБ/сек
                local speed=$(echo "scale=2; $speed_download / 1048576" | bc)
                
                # Выводим подробную информацию
                echo -e "Загружено: $(format_size "$size_download")"
                echo -e "Время: $(format_time "$time_total") сек"
                echo -e "Скорость: ${YELLOW}$(format_speed "$speed") MB/s${NC}"
                
                # Обновляем максимальную скорость если текущая больше 0
                if [ "$(echo "$speed > 0" | bc -l)" -eq 1 ] && [ "$(echo "$speed > $max_speed" | bc -l)" -eq 1 ]; then
                    max_speed=$speed
                fi
                successful_test=true
            else
                echo -e "${RED}Ошибка при тестировании${NC}"
            fi
            
            sleep 1
        done
        
        if [ "$successful_test" = true ]; then
            echo -e "\n${GREEN}Максимальная измеренная скорость: ${YELLOW}$(format_speed "$max_speed") MB/s${NC}"
            local speed_mbits=$(echo "scale=1; $max_speed * 8" | bc)
            echo -e "Примерная скорость: ${YELLOW}$(format_speed "$speed_mbits") Mbit/s${NC}"
            return 0
        else
            echo -e "\n${RED}Не удалось измерить скорость. Проверьте подключение к интернету.${NC}"
            return 1
        fi
    }

    # Сначала пробуем speedtest-cli
    if command -v speedtest-cli &> /dev/null; then
        if timeout 30 speedtest-cli --simple &>/dev/null; then
            timeout 30 speedtest-cli --simple
        else
            echo -e "${YELLOW}Speedtest.net недоступен, использую альтернативный метод...${NC}"
            test_speed_curl
        fi
    else
        echo -e "${YELLOW}Используется альтернативный метод проверки скорости...${NC}"
        test_speed_curl
    fi
}

# Функция для получения информации о соединении
get_connection_info() {
    echo -e "${YELLOW}Информация о соединении:${NC}"
    echo "---------------------------------"
    log_message "Сбор информации о соединении"
    
    # Вывод информации о сетевых интерфейсах
    echo -e "${GREEN}Сетевые интерфейсы:${NC}"
    ip -c addr show

    # Вывод информации о маршрутах
    echo -e "\n${GREEN}Маршруты:${NC}"
    ip -c route show

    # Вывод информации о DNS
    echo -e "\n${GREEN}DNS-серверы:${NC}"
    cat /etc/resolv.conf | grep "nameserver"

    # Вывод информации о текущем IP-адресе
    echo -e "\n${GREEN}Внешний IP-адрес:${NC}"
    curl -s ifconfig.me
    echo # Новая строка после IP
}

# Функция для вывода справки
show_help() {
    echo "Использование: $0 [ОПЦИИ]"
    echo "Опции:"
    echo "  -h, --help     Показать эту справку"
    echo "  -c, --check    Только проверка соединения"
    echo "  -q, --quality  Проверка качества соединения"
    echo "  -i, --info     Информация о соединении"
    echo "  -a, --all      Выполнить все проверки (по умолчанию)"
}

# Обработка аргументов командной строки
case "$1" in
    -h|--help)
        show_help
        exit 0
        ;;
    -c|--check)
        check_internet
        exit $?
        ;;
    -q|--quality)
        check_internet && check_connection_quality
        exit $?
        ;;
    -i|--info)
        check_internet && get_connection_info
        exit $?
        ;;
    -a|--all|"")
        # Проверка наличия необходимых утилит
        utilities=("ping" "ip" "curl")
        for utility in "${utilities[@]}"; do
            check_utility "$utility" || install_utilities
        done

        # Выполнение всех проверок
        if check_internet; then
            check_connection_quality
            get_connection_info
        else
            echo -e "${RED}Попробуйте проверить соединение позже.${NC}"
            exit 1
        fi
        ;;
    *)
        echo -e "${RED}Неизвестный параметр: $1${NC}"
        show_help
        exit 1
        ;;
esac
