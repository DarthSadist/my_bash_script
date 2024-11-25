#!/bin/bash

# Функция для вывода справки
show_help() {
    echo "Использование: $0 [ОПЦИИ] <старое_имя> <новое_имя>"
    echo "Опции:"
    echo "  -h, --help           Показать эту справку"
    echo "  -i, --interactive    Интерактивный режим"
    echo "  -b, --backup         Создать резервную копию"
    echo "  -r, --recursive      Рекурсивный режим для каталогов"
    echo "  -f, --force          Принудительное переименование"
    echo "  -v, --verbose        Подробный вывод"
    exit 0
}

# Функция для создания лог-файла
log_operation() {
    local message="$1"
    local log_file="/tmp/rename_operations.log"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$log_file"
}

# Функция для создания резервной копии
create_backup() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "${file}.backup"
        log_operation "Создана резервная копия файла: $file"
        return 0
    fi
    return 1
}

# Функция для проверки прав доступа
check_permissions() {
    local file="$1"
    if [ ! -w "$(dirname "$file")" ]; then
        echo "Ошибка: нет прав на запись в каталог $(dirname "$file")"
        return 1
    fi
    if [ -e "$file" ] && [ ! -w "$file" ]; then
        echo "Ошибка: нет прав на изменение файла $file"
        return 1
    fi
    return 0
}

# Инициализация переменных
interactive=false
backup=false
recursive=false
force=false
verbose=false

# Обработка параметров командной строки
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -i|--interactive)
            interactive=true
            shift
            ;;
        -b|--backup)
            backup=true
            shift
            ;;
        -r|--recursive)
            recursive=true
            shift
            ;;
        -f|--force)
            force=true
            shift
            ;;
        -v|--verbose)
            verbose=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Проверка количества оставшихся аргументов
if [ $# -ne 2 ]; then
    echo "Ошибка: требуется указать старое и новое имя"
    show_help
fi

old_pattern="$1"
new_pattern="$2"

# Функция переименования
rename_file() {
    local old_file="$1"
    local new_file="$2"

    # Проверка существования файла
    if [ ! -e "$old_file" ]; then
        echo "Ошибка: файл '$old_file' не существует"
        return 1
    fi

    # Проверка прав доступа
    if ! check_permissions "$old_file"; then
        return 1
    fi

    # Проверка существования целевого файла
    if [ -e "$new_file" ] && [ "$force" = false ]; then
        if [ "$interactive" = true ]; then
            read -p "Файл '$new_file' существует. Перезаписать? (y/n) " answer
            if [[ ! $answer =~ ^[Yy]$ ]]; then
                return 1
            fi
        else
            echo "Ошибка: файл '$new_file' уже существует"
            return 1
        fi
    fi

    # Создание резервной копии
    if [ "$backup" = true ]; then
        create_backup "$old_file"
    fi

    # Переименование
    mv "$old_file" "$new_file"
    if [ $? -eq 0 ]; then
        [ "$verbose" = true ] && echo "Успешно переименован: $old_file -> $new_file"
        log_operation "Переименован файл: $old_file -> $new_file"
        return 0
    else
        echo "Ошибка при переименовании '$old_file'"
        return 1
    fi
}

# Основная логика
if [ "$recursive" = true ]; then
    # Рекурсивный поиск и переименование
    find . -name "$old_pattern" -type f | while read -r file; do
        new_name=$(echo "$file" | sed "s/$old_pattern/$new_pattern/")
        rename_file "$file" "$new_name"
    done
else
    # Переименование одного файла
    rename_file "$old_pattern" "$new_pattern"
fi
