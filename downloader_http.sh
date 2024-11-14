#!/bin/bash

# Проверка, был ли передан аргумент (URL)
if [ "$1" == "" ]; then
    echo "usage: $0 URL"
    exit 1
fi

# Извлечение имени хоста из URL
# Удаляем 'http://' и оставляем только хост
HOST=$(echo $1 | sed 's|http://||' | sed -r 's|([^/]+)/.*|\1|')

# Извлечение имени файла из URL
# Оставляем только часть после последнего '/'
FILENAME=$(echo "$1" | sed -r 's|.*/(.*)|\1|')

# Извлечение пути к файлу из URL
# Удаляем 'http://', имя хоста и имя файла
PATH=$(echo "$1" | sed 's|http://||' | sed -r "s|$HOST||" | sed "s|/$FILENAME||")

# Установка порта для HTTP
PORT=80

# Формирование заголовков для HTTP-запроса
HEADERS="HTTP/1.1\r\nHost: $HOST\r\nConnection: close\r\nContent-Length: 0\r\n\r\n"

# Путь к временному файлу для хранения ответа
TEMP_FILE="/tmp/dlfile"

# Установка TCP-соединения с хостом и портом
exec 3<>/dev/tcp/$HOST/$PORT

# Отправка GET-запроса
echo -e "GET $PATH/$FILENAME $HEADERS" >&3

# Чтение ответа от сервера и запись его во временный файл
/bin/cat <&3 > $TEMP_FILE

# Извлечение только тела ответа
/usr/bin/tail $TEMP_FILE -n +$((`/bin/sed $TEMP_FILE -e '/^\r$/q' | /usr/bin/wc -l` + 1)) > $FILENAME

# Удаление временного файла
/bin/rm $TEMP_FILE

# Вывод сообщения об успешном завершении
echo "File downloaded as: $FILENAME"

