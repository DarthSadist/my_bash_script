#!/bin/bash

# Функция проверки существующих установок
check_existing_installation() {
    local USER_HOME="$1"
    local has_existing=false
    local message=""

    echo "Проверка существующих установок..."

    # Проверка прав доступа к домашней директории
    if [ ! -r "$USER_HOME" ]; then
        echo "Ошибка: нет прав на чтение домашней директории '$USER_HOME'"
        return 1
    fi

    # Проверка Zsh
    if command -v zsh >/dev/null 2>&1; then
        echo "Найден: Zsh"
        has_existing=true
    fi

    # Проверка Oh My Zsh
    if [ -d "$USER_HOME/.oh-my-zsh" ]; then
        echo "Найден: Oh My Zsh"
        has_existing=true
    fi

    # Проверка Powerlevel10k
    if [ -d "$USER_HOME/.powerlevel10k" ]; then
        echo "Найден: Powerlevel10k"
        has_existing=true
    fi

    # Проверка плагинов
    local plugins_dir="${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}/plugins"
    if [ -d "$plugins_dir" ]; then
        if [ -d "$plugins_dir/zsh-syntax-highlighting" ]; then
            echo "Найден: zsh-syntax-highlighting"
            has_existing=true
        fi
        if [ -d "$plugins_dir/zsh-autosuggestions" ]; then
            echo "Найден: zsh-autosuggestions"
            has_existing=true
        fi
    fi

    # Если найдены существующие установки
    if [ "$has_existing" = true ]; then
        echo -e "\nНайдены установленные компоненты. Что делаем?"
        echo "1) Удалить существующие установки и продолжить"
        echo "2) Отменить установку"
        
        while true; do
            read -r choice
            case $choice in
                1)
                    remove_existing_installation "$USER_HOME"
                    return $?
                    ;;
                2)
                    echo "Установка отменена"
                    exit 0
                    ;;
                *)
                    echo "Введите 1 или 2"
                    ;;
            esac
        done
    fi
    
    return 0
}

# Функция удаления существующих установок
remove_existing_installation() {
    local USER_HOME="$1"
    local current_shell=$(echo $SHELL)
    
    echo "Начинаем удаление существующих установок..."
    
    # Возврат к bash если текущая оболочка zsh
    if [[ "$current_shell" == *"zsh"* ]]; then
        echo "Меняем оболочку на bash..."
        if ! chsh -s $(which bash) $(whoami); then
            echo "Ошибка при смене оболочки на bash"
            return 1
        fi
    fi

    # Удаление Oh My Zsh
    if [ -d "$USER_HOME/.oh-my-zsh" ]; then
        echo "Удаляем Oh My Zsh..."
        rm -rf "$USER_HOME/.oh-my-zsh" 2>/dev/null || sudo rm -rf "$USER_HOME/.oh-my-zsh"
    fi

    # Удаление Powerlevel10k
    if [ -d "$USER_HOME/.powerlevel10k" ]; then
        echo "Удаляем Powerlevel10k..."
        rm -rf "$USER_HOME/.powerlevel10k" 2>/dev/null || sudo rm -rf "$USER_HOME/.powerlevel10k"
    fi

    # Удаление конфигурационных файлов
    echo "Удаляем конфигурационные файлы..."
    rm -f "$USER_HOME/.zshrc" "$USER_HOME/.zsh_history" "$USER_HOME/.zcompdump"* "$USER_HOME/.p10k.zsh" 2>/dev/null

    # Удаление плагинов
    local plugins_dir="${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}/plugins"
    if [ -d "$plugins_dir" ]; then
        echo "Удаляем плагины..."
        rm -rf "$plugins_dir/zsh-syntax-highlighting" "$plugins_dir/zsh-autosuggestions" 2>/dev/null || \
        sudo rm -rf "$plugins_dir/zsh-syntax-highlighting" "$plugins_dir/zsh-autosuggestions"
    fi

    # Удаление Zsh
    if command -v zsh >/dev/null 2>&1; then
        echo "Удаляем Zsh..."
        if [[ "$current_shell" == *"zsh"* ]]; then
            echo "Zsh будет удален после перезапуска терминала"
            echo "Выполните команду после завершения установки:"
            echo "sudo apt-get remove --purge -y zsh && sudo apt-get autoremove -y"
        else
            sudo DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y zsh
            sudo apt-get autoremove -y
        fi
    fi

    echo "Удаление завершено"
    return 0
}

# Функция установки
install_zsh() {
    local USER_HOME="$1"
    local INSTALL_TYPE="$2"

    echo "Шаг 1: Проверка существующих установок"
    if ! check_existing_installation "$USER_HOME"; then
        echo "Ошибка при проверке установок"
        return 1
    fi

    echo "Шаг 2: Обновление списка пакетов"
    if [ "$INSTALL_TYPE" = "root" ]; then
        apt-get update -qq
    else
        sudo apt-get update -qq
    fi

    echo "Шаг 3: Установка Zsh"
    if ! command -v zsh >/dev/null 2>&1; then
        if [ "$INSTALL_TYPE" = "root" ]; then
            DEBIAN_FRONTEND=noninteractive apt-get install -y zsh
        else
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y zsh
        fi
    fi

    echo "Шаг 4: Установка дополнительных пакетов"
    local packages=("git" "curl" "wget" "fonts-powerline")
    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg"; then
            if [ "$INSTALL_TYPE" = "root" ]; then
                DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
            else
                sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
            fi
        fi
    done

    echo "Шаг 5: Установка Oh My Zsh"
    if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
        [ -f "$USER_HOME/.zshrc" ] && mv "$USER_HOME/.zshrc" "$USER_HOME/.zshrc.pre-oh-my-zsh"
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    echo "Шаг 6: Установка плагинов"
    local plugins_dir="${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}/plugins"
    mkdir -p "$plugins_dir"
    
    if [ ! -d "$plugins_dir/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugins_dir/zsh-syntax-highlighting"
    fi
    
    if [ ! -d "$plugins_dir/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions.git "$plugins_dir/zsh-autosuggestions"
    fi
    
    if [ ! -d "$USER_HOME/.powerlevel10k" ]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$USER_HOME/.powerlevel10k"
    fi

    echo "Шаг 7: Установка конфигурационного файла из репозитория"
    echo "Клонирование репозитория с конфигурацией..."
    
    # Создаем временную директорию и клонируем репозиторий
    TEMP_DIR=$(mktemp -d)
    if ! git clone git@github.com:DarthSadist/my_zsh.git "$TEMP_DIR"; then
        echo "Ошибка при клонировании репозитория с конфигурацией"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Копируем конфигурационный файл
    if [ -f "$TEMP_DIR/.zshrc" ]; then
        cp "$TEMP_DIR/.zshrc" "$USER_HOME/.zshrc"
        echo "Конфигурационный файл успешно установлен из репозитория"
    else
        echo "Ошибка: конфигурационный файл .zshrc не найден в репозитории"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Очищаем временную директорию
    rm -rf "$TEMP_DIR"

    # Установка прав на файлы
    chown -R $(whoami):$(whoami) "$USER_HOME/.oh-my-zsh" "$USER_HOME/.zshrc" "$USER_HOME/.powerlevel10k" 2>/dev/null

    echo -e "\nУстановка завершена!"
    echo "Для завершения настройки:"
    echo "1. Закройте текущий терминал"
    echo "2. Откройте новый терминал"
    echo "3. Выполните команду: p10k configure"
}

# Основная функция
main() {
    echo "Установка Zsh"
    echo "Выберите вариант установки:"
    echo "1) Установка для текущего пользователя"
    echo "2) Установка для root"
    echo "3) Отмена установки"
    
    while true; do
        read -r choice
        case $choice in
            1)
                echo "Установка для текущего пользователя..."
                install_zsh "$HOME" "user"
                break
                ;;
            2)
                if [ "$EUID" -ne 0 ]; then
                    echo "Для установки root требуются права администратора"
                    exit 1
                fi
                echo "Установка для root..."
                install_zsh "/root" "root"
                break
                ;;
            3)
                echo "Установка отменена"
                exit 0
                ;;
            *)
                echo "Введите 1, 2 или 3"
                ;;
        esac
    done
}

main
