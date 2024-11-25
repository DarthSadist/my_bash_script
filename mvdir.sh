#!/bin/bash

# Указываем интерпретатор, с помощью которого будет выполняться скрипт.

# Определяем ANSI-коды для цветов и стилей текста
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Директория для логов
LOG_DIR="/var/log/move_directory"
LOG_FILE="$LOG_DIR/move_directory.log"
BACKUP_DIR="/tmp/mvdir_backup"

# Функция для создания горизонтальной линии
print_line() {
    printf "%$(tput cols)s\n" | tr ' ' '─'
}

# Функция для создания заголовка
print_header() {
    local text="$1"
    local width=$(tput cols)
    local padding=$(( (width - ${#text} - 2) / 2 ))
    print_line
    printf "%${padding}s %s %${padding}s\n" "" "${BOLD}${BLUE}$text${NC}" ""
    print_line
}

# Функция для вывода сообщений с форматированием
function log_message {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$1"
    local prefix="$2"
    
    # Если префикс не указан, используем пустую строку
    [ -z "$prefix" ] && prefix="│"
    
    # Записываем в лог-файл без форматирования
    echo -e "[$timestamp] $message" | sed 's/\x1b\[[0-9;]*m//g' | sudo tee -a "$LOG_FILE" >/dev/null
    
    # Выводим на экран с форматированием
    echo -e "$prefix ${message}"
}

# Функция для отображения прогресса
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((percentage * width / 100))
    local empty=$((width - filled))
    
    printf "\r│ ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%%" $percentage
}

# Функция для обработки завершения скрипта
function cleanup {
    # Выводим сообщение о завершении работы скрипта
    log_message "${RED}Скрипт завершен.${NC}"
    exit 1  # Выходим с кодом 1 (ошибка)
}

# Устанавливаем обработку сигналов (SIGINT и SIGTERM) для корректного завершения работы скрипта
trap cleanup SIGINT SIGTERM

# Проверяем, что количество аргументов, переданных скрипту, равно 2
if [ "$#" -ne 2 ]; then
    # Если аргументов не 2, выводим сообщение об ошибке и завершаем выполнение скрипта
    log_message "${RED}2 аргумента требуются: директория, которую нужно переместить, и целевая директория${NC}"
    exit 1  # Завершаем выполнение скрипта с кодом 1 (ошибка)
fi

# Присваиваем аргументы переменным для удобства
SRC_DIR="$1"  # Исходная директория, которую нужно переместить
DEST_DIR="$2"  # Целевая директория, куда нужно переместить исходную директорию

# Проверяем, существует ли исходная директория
if [ ! -d "$SRC_DIR" ]; then
    # Если директория не существует или это не директория, выводим сообщение об ошибке
    log_message "${RED}Ошибка: $SRC_DIR не существует или это не директория${NC}"
    exit 1  # Завершаем выполнение скрипта с кодом 1 (ошибка)
fi

# Проверяем, существует ли целевая директория
if [ ! -d "$DEST_DIR" ]; then
    # Если директория не существует или это не директория, выводим сообщение об ошибке
    log_message "${RED}Ошибка: $DEST_DIR не существует или это не директория${NC}"
    exit 1  # Завершаем выполнение скрипта с кодом 1 (ошибка)
fi

# Проверяем, что у нас есть права на чтение исходной директории
if [ ! -r "$SRC_DIR" ]; then
    # Если нет прав на чтение, выводим сообщение об ошибке и завершаем выполнение
    log_message "${RED}Ошибка: нет прав на чтение $SRC_DIR${NC}"
    exit 1  # Завершаем выполнение скрипта с кодом 1 (ошибка)
fi
# Проверяем, что у нас есть права на запись в целевую директорию
if [ ! -w "$DEST_DIR" ]; then
    # Если нет прав на запись, выводим сообщение об ошибке и завершаем выполнение
    log_message "${RED}Ошибка: нет прав на запись в $DEST_DIR${NC}"
    exit 1  # Завершаем выполнение скрипта с кодом 1 (ошибка)
fi

# Проверяем, существует ли директория с таким же именем в целевой директории
if [ -d "$DEST_DIR/$(basename "$SRC_DIR")" ]; then
    # Если директория с тем же именем уже существует, выводим предупреждение
    log_message "${RED}Предупреждение: директория $(basename "$SRC_DIR") уже существует в $DEST_DIR.${NC}"
    # Предлагаем пользователю выбрать, что делать: перезаписать или отменить операцию
    read -p "Хотите перезаписать её? (y/n): " choice
    if [[ "$choice" != "y" ]]; then
        # Если пользователь не хочет перезаписывать, выводим сообщение и завершаем операцию
        log_message "${RED}Операция отменена пользователем.${NC}"
        exit 1  # Завершаем выполнение скрипта с кодом 1 (ошибка)
    fi
fi

# Функция для проверки свободного места
check_free_space() {
    local src_size=$(du -s "$1" | cut -f1)
    local dest_free=$(df "$2" | tail -1 | awk '{print $4}')
    
    if [ $src_size -gt $dest_free ]; then
        log_message "${RED}Ошибка: Недостаточно места на целевом диске${NC}"
        return 1
    fi
    return 0
}

# Функция для создания резервной копии
create_backup() {
    local src="$1"
    local backup_path="$BACKUP_DIR/$(basename "$src")_$(date +%Y%m%d_%H%M%S)"
    
    log_message "${YELLOW}Создание резервной копии...${NC}"
    mkdir -p "$BACKUP_DIR"
    if cp -r "$src" "$backup_path"; then
        log_message "${GREEN}Резервная копия создана: $backup_path${NC}"
        return 0
    else
        log_message "${RED}Ошибка создания резервной копии${NC}"
        return 1
    fi
}

# Функция для проверки прав доступа
check_permissions() {
    if [ ! -r "$1" ] || [ ! -w "$1" ]; then
        log_message "${RED}Ошибка: Недостаточно прав для работы с $1${NC}"
        return 1
    fi
    if [ ! -w "$2" ]; then
        log_message "${RED}Ошибка: Недостаточно прав для записи в $2${NC}"
        return 1
    fi
    return 0
}

# Проверяем права доступа
if ! check_permissions "$SRC_DIR" "$DEST_DIR"; then
    exit 1
fi

# Проверяем свободное место
if ! check_free_space "$SRC_DIR" "$DEST_DIR"; then
    exit 1
fi

# Создаем резервную копию
if ! create_backup "$SRC_DIR"; then
    log_message "${YELLOW}Продолжить без резервной копии? (y/n)${NC}"
    read -r answer
    if [ "$answer" != "y" ]; then
        cleanup
    fi
fi

# Перемещаем директорию с отображением прогресса
print_header "ПЕРЕМЕЩЕНИЕ ДИРЕКТОРИИ"
log_message "${BOLD}Исходная директория:${NC} $SRC_DIR"
log_message "${BOLD}Целевая директория:${NC} $DEST_DIR"
print_line

# Проверяем права доступа
log_message "🔍 Проверка прав доступа..."
if ! check_permissions "$SRC_DIR" "$DEST_DIR"; then
    log_message "${RED}✘ Ошибка: недостаточно прав${NC}"
    exit 1
fi
log_message "${GREEN}✓ Права доступа проверены${NC}"

# Проверяем свободное место
log_message "🔍 Проверка свободного места..."
if ! check_free_space "$SRC_DIR" "$DEST_DIR"; then
    log_message "${RED}✘ Ошибка: недостаточно места${NC}"
    exit 1
fi
log_message "${GREEN}✓ Достаточно места${NC}"

# Создаем резервную копию
log_message "📦 Создание резервной копии..."
if ! create_backup "$SRC_DIR"; then
    log_message "${YELLOW}⚠ Внимание: Продолжить без резервной копии? (y/n)${NC}"
    read -r answer
    if [ "$answer" != "y" ]; then
        cleanup
    fi
fi
log_message "${GREEN}✓ Резервная копия создана${NC}"

print_line
log_message "🚀 Начинаем перемещение..."
rsync -ah --info=progress2 "$SRC_DIR" "$DEST_DIR" 2>&1 | while read -r line; do
    if [[ $line =~ ^[0-9]+% ]]; then
        percent=$(echo "$line" | grep -o '[0-9]*%' | grep -o '[0-9]*')
        show_progress $percent 100
    fi
done
echo # Новая строка после прогресс-бара

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    print_line
    log_message "${GREEN}✓ Директория успешно перемещена!${NC}"
    rm -rf "$SRC_DIR"
    print_line
    exit 0
else
    print_line
    log_message "${RED}✘ Ошибка! Не удалось переместить директорию${NC}"
    log_message "${YELLOW}↺ Восстанавливаем из резервной копии...${NC}"
    if [ -d "$BACKUP_DIR" ]; then
        cp -r "$BACKUP_DIR/$(basename "$SRC_DIR")"* "$SRC_DIR"
        log_message "${GREEN}✓ Восстановление выполнено успешно${NC}"
    fi
    print_line
    exit 1
fi
