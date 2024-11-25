#!/bin/bash

# Установка цветов для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для вывода сообщений об ошибках
error() {
    echo -e "${RED}Ошибка: $1${NC}" >&2
    exit 1
}

# Функция для вывода информационных сообщений
info() {
    echo -e "${GREEN}$1${NC}"
}

# Функция для вывода предупреждений
warn() {
    echo -e "${YELLOW}Предупреждение: $1${NC}"
}

# Функция проверки зависимостей
check_dependencies() {
    local deps=("nc" "openssl" "curl")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "Требуется установить $dep"
        fi
    done
}

# Функция проверки доступности хоста
check_host() {
    local host=$1
    local port=$2
    if ! nc -z -w5 "$host" "$port" 2>/dev/null; then
        error "Хост $host недоступен на порту $port"
    fi
}

# Функция для парсинга URL
parse_url() {
    local url=$1
    if [[ "$url" =~ ^https?:// ]]; then
        PROTOCOL=$(echo "$url" | sed -E 's|^(https?)://.*|\1|')
        HOST=$(echo "$url" | sed -E 's|^https?://([^/]+)/.*|\1|')
        PATH_URL=$(echo "$url" | sed -E "s|^https?://$HOST||")
        FILENAME=$(basename "$PATH_URL")
        
        if [ "$PROTOCOL" = "https" ]; then
            PORT=443
        else
            PORT=80
        fi
    else
        error "Неверный формат URL. Используйте: http:// или https://"
    fi
}

# Функция для создания директории загрузок
ensure_download_dir() {
    if [ -n "$OUTPUT_DIR" ]; then
        DOWNLOAD_DIR="$OUTPUT_DIR"
    else
        DOWNLOAD_DIR="$HOME/Загрузки"
    fi

    if [ ! -d "$DOWNLOAD_DIR" ]; then
        mkdir -p "$DOWNLOAD_DIR" || error "Не удалось создать директорию $DOWNLOAD_DIR"
    fi
}

# Функция для загрузки файла
download_file() {
    local temp_headers="/tmp/headers_$$"
    local temp_body="/tmp/body_$$"
    
    # Использование curl для загрузки с поддержкой HTTPS и редиректов
    if ! curl -L -s -D "$temp_headers" "$1" -o "$temp_body"; then
        rm -f "$temp_headers" "$temp_body"
        error "Ошибка при загрузке файла"
    fi
    
    # Проверка кода ответа
    local status_code=$(head -n1 "$temp_headers" | cut -d' ' -f2)
    if [ "$status_code" != "200" ]; then
        rm -f "$temp_headers" "$temp_body"
        error "Сервер вернул код $status_code"
    fi
    
    # Перемещение файла в директорию загрузок
    mv "$temp_body" "$DOWNLOAD_DIR/$FILENAME"
    rm -f "$temp_headers"
    
    info "Файл успешно загружен в: $DOWNLOAD_DIR/$FILENAME"
}

# Обработка параметров командной строки
while getopts "o:h" opt; do
    case $opt in
        o)
            OUTPUT_DIR="$OPTARG"
            ;;
        h)
            echo "Использование: $0 [-o output_dir] URL"
            echo "  -o: директория для сохранения файла"
            echo "  -h: показать эту справку"
            exit 0
            ;;
        \?)
            error "Неверный параметр: -$OPTARG"
            ;;
    esac
done

shift $((OPTIND-1))

# Проверка наличия URL
if [ -z "$1" ]; then
    error "Укажите URL для загрузки"
fi

# Основной код
check_dependencies
parse_url "$1"
check_host "$HOST" "$PORT"
ensure_download_dir
download_file "$1"
