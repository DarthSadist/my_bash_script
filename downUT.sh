#!/bin/bash

# Функция для установки yt-dlp
install_yt_dlp() {
    echo "Установка yt-dlp..."
    if command -v pip &> /dev/null; then
        pip install -U yt-dlp
    elif command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y python3-pip
        pip3 install -U yt-dlp
    elif command -v brew &> /dev/null; then
        brew install yt-dlp
    else
        echo "Не удалось установить yt-dlp. Установите его вручную."
        exit 1
    fi
}

# Проверяем, установлен ли Python
if ! command -v python3 &> /dev/null; then
    echo "Python не установлен. Устанавливаем Python..."
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y python3 python3-pip
    elif command -v brew &> /dev/null; then
        brew install python
    else
        echo "Не удалось установить Python. Установите его вручную."
        exit 1
    fi
fi

# Проверяем, установлен ли yt-dlp
if ! command -v yt-dlp &> /dev/null; then
    install_yt_dlp
fi

# Проверяем, передан ли аргумент с URL
if [ -z "$1" ]; then
    echo "Использование: $0 <URL_видео_на_YouTube>"
    exit 1
fi

# Скачивание звуковой дорожки
echo "Скачивание звуковой дорожки из видео: $1"
yt-dlp -x --audio-format mp3 "$1"

# Проверяем, было ли скачивание успешным
if [ $? -eq 0 ]; then
    echo "Скачивание завершено успешно!"
else
    echo "Произошла ошибка при скачивании звуковой дорожки."
fi

