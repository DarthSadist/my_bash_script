#!/bin/bash

# Определяем цвета и стили
GREEN="\e[32m"
PURPLE="\e[35m"
YELLOW="\e[33m"
ORANGE="\e[38;5;214m"
BLUE="\e[34m"
PINK="\e[38;5;206m"
RED="\e[31m"
CYAN="\e[36m"
BOLD="\e[1m"
DIM="\e[2m"
RESET="\e[0m"

# Определяем символы
CHECK_MARK="✓"
CROSS_MARK="✗"
ARROW="→"
FOLDER="📁"
WARNING="⚠️"

# Определяем пути к папкам
DOWNLOADS_DIR="$HOME/Загрузки"
IMAGES_DIR="$HOME/Изображения"
MUSIC_DIR="$HOME/Музыка"
VIDEOS_DIR="$HOME/Видео"
DOCUMENTS_DIR="$HOME/Документы"
PROGRAM_DIR="$HOME/Программы"
ARCHIVES_DIR="$HOME/Archives"
TRASH_DIR="$HOME/.local/share/Trash/files"

# Создаем лог-файл
LOG_DIR="$HOME/.logs"
LOG_FILE="$LOG_DIR/cleanup_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR"

# Функция для вывода сообщений
log_message() {
    local message="$1"
    local type="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$type" in
        "info")
            echo -e "${CYAN}${BOLD}[INFO]${RESET} $message" | tee -a "$LOG_FILE"
            ;;
        "success")
            echo -e "${GREEN}${BOLD}[${CHECK_MARK}]${RESET} $message" | tee -a "$LOG_FILE"
            ;;
        "warning")
            echo -e "${YELLOW}${BOLD}[${WARNING}]${RESET} $message" | tee -a "$LOG_FILE"
            ;;
        "error")
            echo -e "${RED}${BOLD}[${CROSS_MARK}]${RESET} $message" | tee -a "$LOG_FILE"
            ;;
        *)
            echo -e "$message" | tee -a "$LOG_FILE"
            ;;
    esac
}

# Функция для отображения прогресса
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((percentage * width / 100))
    local empty=$((width - filled))
    
    printf "\r${DIM}[${RESET}"
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "${DIM}]${RESET} %3d%%" $percentage
}

# Функция для создания разделителя
print_separator() {
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '─'
}

# Функция для отображения заголовка
print_header() {
    local title="$1"
    local width=${COLUMNS:-$(tput cols)}
    local padding=$(( (width - ${#title} - 2) / 2 ))
    
    echo
    print_separator
    printf "%${padding}s${BOLD}%s${RESET}%${padding}s\n" "" "$title" ""
    print_separator
}

# Создаем необходимые папки
create_directories() {
    local dirs=("$PROGRAM_DIR" "$ARCHIVES_DIR" "$DOCUMENTS_DIR" "$LOG_DIR")
    local total=${#dirs[@]}
    local current=0
    
    print_header "Подготовка директорий"
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir" && log_message "Создана директория: $dir" "success" || \
                log_message "Ошибка создания директории: $dir" "error"
        fi
        ((current++))
        show_progress $current $total
    done
    echo
}

# Функция для перемещения файлов
move_files() {
    local src="$1"
    local dest="$2"
    local extensions=($3)
    local type_name="$4"
    local color="$5"
    local total_files=0
    local moved_files=0
    
    # Подсчитываем общее количество файлов
    for ext in "${extensions[@]}"; do
        total_files=$((total_files + $(find "$src" -maxdepth 1 -type f -name "*.$ext" | wc -l)))
    done
    
    if [ $total_files -eq 0 ]; then
        results["$type_name"]="0 $color"
        return
    fi
    
    log_message "Обработка $type_name..." "info"
    
    for ext in "${extensions[@]}"; do
        for file in "$src"/*."$ext"; do
            if [ -f "$file" ]; then
                if mv "$file" "$dest/" 2>/dev/null; then
                    ((moved_files++))
                    show_progress $moved_files $total_files
                else
                    log_message "Ошибка перемещения: $file" "error"
                fi
            fi
        done
    done
    
    echo
    results["$type_name"]="$moved_files $color"
}

# Функция для перемещения документов
move_documents() {
    local src="$1"
    local dest="$2"
    local extensions=("pdf" "doc" "docx" "xls" "xlsx" "ppt" "pptx" "txt" "rtf" "odt" "ods" "odp")
    
    move_files "$src" "$dest" "${extensions[*]}" "Документы" "$BLUE"
    
    # Обработка файлов без расширения
    local files_no_ext=("$src"/*)
    local count=0
    
    for file in "${files_no_ext[@]}"; do
        if [ -f "$file" ] && [[ ! "$file" =~ \. ]]; then
            if mv "$file" "$dest/" 2>/dev/null; then
                ((count++))
            else
                log_message "Ошибка перемещения: $file" "error"
            fi
        fi
    done
    
    if [ $count -gt 0 ]; then
        results["Документы без расширения"]="$count $BLUE"
    fi
}

# Функция для перемещения исполняемых файлов
move_executables() {
    local src="$1"
    local dest="$2"
    local count=0
    local total=$(find "$src" -maxdepth 1 -type f -executable | wc -l)
    
    log_message "Обработка исполняемых файлов..." "info"
    
    while IFS= read -r -d '' file; do
        if mv "$file" "$dest/" 2>/dev/null; then
            ((count++))
            show_progress $count $total
        else
            log_message "Ошибка перемещения: $file" "error"
        fi
    done < <(find "$src" -maxdepth 1 -type f -executable -print0)
    
    echo
    results["Исполняемые файлы"]="$count $PINK"
}

# Функция для очистки пустых директорий
cleanup_empty_dirs() {
    local dir="$1"
    find "$dir" -type d -empty -delete 2>/dev/null
    log_message "Удалены пустые директории" "success"
}

# Функция для отображения статистики
show_statistics() {
    print_header "Статистика очистки"
    
    local total_files=0
    for key in "${!results[@]}"; do
        local count=$(echo "${results[$key]}" | cut -d' ' -f1)
        local color=$(echo "${results[$key]}" | cut -d' ' -f2)
        total_files=$((total_files + count))
        printf "${BOLD}%-25s${RESET}: ${color}%d${RESET} файлов\n" "$key" "$count"
    done
    
    print_separator
    printf "${BOLD}%-25s${RESET}: ${GREEN}%d${RESET} файлов\n" "Всего обработано" "$total_files"
    echo
}

# Основной блок скрипта
print_header "Очистка загрузок"

# Инициализация массива для хранения результатов
declare -A results

# Создаем необходимые директории
create_directories

# Определяем типы файлов
declare -A file_types=(
    ["Изображения"]="jpg jpeg png gif bmp tiff webp svg ico"
    ["Музыка"]="mp3 wav flac ogg m4a aac wma"
    ["Видео"]="mp4 mkv avi mov wmv MOV flv webm"
    ["Архивы"]="zip tgz tar gz bz2 xz rar 7z"
    ["DEB пакеты"]="deb"
)

# Обработка файлов по типам
for type in "${!file_types[@]}"; do
    case "$type" in
        "Изображения")
            move_files "$DOWNLOADS_DIR" "$IMAGES_DIR" "${file_types[$type]}" "$type" "$PURPLE"
            ;;
        "Музыка")
            move_files "$DOWNLOADS_DIR" "$MUSIC_DIR" "${file_types[$type]}" "$type" "$ORANGE"
            ;;
        "Видео")
            move_files "$DOWNLOADS_DIR" "$VIDEOS_DIR" "${file_types[$type]}" "$type" "$GREEN"
            ;;
        "Архивы")
            move_files "$DOWNLOADS_DIR" "$ARCHIVES_DIR" "${file_types[$type]}" "$type" "$YELLOW"
            ;;
        "DEB пакеты")
            move_files "$DOWNLOADS_DIR" "$PROGRAM_DIR" "${file_types[$type]}" "$type" "$PINK"
            ;;
    esac
done

# Обработка документов и исполняемых файлов
move_documents "$DOWNLOADS_DIR" "$DOCUMENTS_DIR"
move_executables "$DOWNLOADS_DIR" "$PROGRAM_DIR"

# Очистка пустых директорий
cleanup_empty_dirs "$DOWNLOADS_DIR"

# Показываем статистику
show_statistics

log_message "Очистка завершена! Лог сохранен в: $LOG_FILE" "success"
