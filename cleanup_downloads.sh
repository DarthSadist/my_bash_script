#!/bin/bash

# Определяем цвета
GREEN="\e[32m"   # Зеленый
PURPLE="\e[35m"  # Фиолетовый
YELLOW="\e[33m"  # Желтый
ORANGE="\e[38;5;214m"  # Оранжевый
BLUE="\e[34m"    # Синий
PINK="\e[38;5;206m"    # Розовый
RED="\e[31m"     # Красный
RESET="\e[0m"    # Сброс цвета

# Определяем пути к папкам
DOWNLOADS_DIR="$HOME/Загрузки"
IMAGES_DIR="$HOME/Изображения"
MUSIC_DIR="$HOME/Музыка"
VIDEOS_DIR="$HOME/Видео"
DOCUMENTS_DIR="$HOME/Документы"
PROGRAM_DIR="$HOME/Программы"
ARCHIVES_DIR="$HOME/Archives"

# Создаем необходимые папки, если они не существуют
mkdir -p "$PROGRAM_DIR" "$ARCHIVES_DIR" "$DOCUMENTS_DIR"

# Инициализация массива для хранения результатов
declare -A results

# Функция для перемещения файлов и сбора результатов
move_files() {
    local src="$1"
    local dest="$2"
    local extensions=($3)
    local type_name="$4"
    local color="$5"

    local count=0  # Счетчик перемещенных файлов

    shopt -s nullglob
    for ext in "${extensions[@]}"; do
        for file in "$src"/*."$ext"; do
            if [ -f "$file" ]; then
                mv "$file" "$dest/" 2> >(grep -v "не удалось" | sed "s/.*/${RED}&${RESET}/")
                count=$((count + 1))
            fi
        done
    done

    results["$type_name"]="$count $color"
    shopt -u nullglob
}

# Функция для перемещения документов
move_documents() {
    local src="$1"
    local dest="$2"
    local extensions=("pdf" "doc" "docx" "xls" "xlsx" "ppt" "pptx" "txt")

    move_files "$src" "$dest" "${extensions[*]}" "Документов" "$BLUE"

    local count=0  # Счетчик перемещенных файлов без расширения

    files=("$src"/*)
    for file in "${files[@]}"; do
        if [ -f "$file" ] && [[ ! "$file" =~ \. ]]; then
            mv "$file" "$dest/" 2> >(grep -v "не удалось" | sed "s/.*/${RED}&${RESET}/")
            count=$((count + 1))
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

    while IFS= read -r -d '' file; do
        mv "$file" "$dest/" 2> >(grep -v "не удалось" | sed "s/.*/${RED}&${RESET}/")
        count=$((count + 1))
    done < <(find "$src" -maxdepth 1 -type f -executable -print0)

    if [ $count -gt 0 ]; then
        results["Исполняемые файлы"]="$count $PINK"
    else
        results["Исполняемые файлы"]="0 $PINK"
    fi
}

# Перемещение файлов по типам
declare -A file_types=( 
    ["Изображения"]="jpg jpeg png gif bmp tiff" 
    ["Музыка"]="mp3 wav flac ogg" 
    ["Видео"]="mp4 mkv avi mov wmv MOV" 
    ["Архивы"]="zip tgz tar gz bz2 xz rar 7z" 
    ["DEB пакеты"]="deb" 
)

# Перемещение файлов разных типов с соответствующими цветами
move_files "$DOWNLOADS_DIR" "$IMAGES_DIR" "${file_types[Изображения]}" "Изображения" "$GREEN"
move_files "$DOWNLOADS_DIR" "$MUSIC_DIR" "${file_types[Музыка]}" "Музыка" "$PURPLE"
move_files "$DOWNLOADS_DIR" "$VIDEOS_DIR" "${file_types[Видео]}" "Видео" "$ORANGE"
move_files "$DOWNLOADS_DIR" "$ARCHIVES_DIR" "${file_types[Архивы]}" "Архивы" "$YELLOW"

# Перемещение всех файлов в "Документы"
move_documents "$DOWNLOADS_DIR" "$DOCUMENTS_DIR"

# Перемещение всех файлов .deb в "Программы"
move_files "$DOWNLOADS_DIR" "$PROGRAM_DIR" "${file_types[DEB пакетов]}" "DEB пакетов" "$PINK"

# Перемещение исполняемых файлов в "Программы"
move_executables "$DOWNLOADS_DIR" "$PROGRAM_DIR"

# Вывод результатов в виде таблицы
echo -e "\n${BLUE}Результаты перемещения файлов:${RESET}"
printf "%-30s %s\n" "Тип файла" "Количество"
echo "-----------------------------------------"

for type in "${!results[@]}"; do
    count_info=${results[$type]}
    count=$(echo $count_info | awk '{print $1}')
    color=$(echo $count_info | awk '{print $2}')
    printf "%-30s ${color}%s${RESET}\n" "$type" "$count"
done

# Сообщение об окончании очистки
echo -e "${RED}Очистка папки Загрузки завершена.${RESET}"
