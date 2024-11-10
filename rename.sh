#!/bin/bash

# Проверяем, переданы ли необходимые аргументы
if [ "$#" -ne 2 ]; then
    echo "Использование: $0 <старое_имя_файла> <новое_имя_файла>"
    exit 1
fi

old_filename="$1"
new_filename="$2"

# Проверяем, существует ли файл
if [ ! -f "$old_filename" ]; then
    echo "Файл '$old_filename' не найден."
    exit 1
fi

# Переименовываем файл
mv "$old_filename" "$new_filename"

# Проверяем, успешно ли выполнена операция
if [ $? -eq 0 ]; then
    echo "Файл переименован в '$new_filename'."
else
    echo "Ошибка при переименовании файла."
fi

