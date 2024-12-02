#!/bin/bash

# Функции для форматированного вывода
print_step() {
    echo -e "\n📦 \033[1m$1\033[0m"
}

print_info() {
    echo -e "   ℹ️  $1"
}

print_success() {
    echo -e "   ✅ $1"
}

print_error() {
    echo -e "   ❌ \033[31m$1\033[0m"
}

# Функция для отображения спиннера
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "   \033[34m%c\033[0m  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Функция для выполнения команды с индикатором прогресса
run_with_spinner() {
    local message=$1
    shift
    echo -ne "   🔄 $message"
    ("$@") &>/dev/null &
    spinner $!
    if [ $? -eq 0 ]; then
        echo -e "\r   ✅ $message"
    else
        echo -e "\r   ❌ $message"
        return 1
    fi
}

# Функция для отображения прогресс-бара
progress_bar() {
    local current=$1
    local total=$2
    local title=$3
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    printf "\r   📊 \033[1m%s\033[0m [" "$title"
    printf "%${completed}s" | tr ' ' '█'
    printf "%${remaining}s" | tr ' ' '░'
    printf "] %d%%" "$percentage"
    
    if [ "$current" -eq "$total" ]; then
        echo
    fi
}

# Функция проверки существующих установок
check_existing_installation() {
    local USER_HOME="$1"
    local has_existing=false
    local message=""

    print_step "Проверка существующих установок"

    # Проверка прав доступа к домашней директории
    if [ ! -r "$USER_HOME" ]; then
        print_error "Нет прав на чтение домашней директории '$USER_HOME'"
        return 1
    fi

    # Проверка Zsh
    if command -v zsh >/dev/null 2>&1; then
        print_info "Найден: Zsh"
        has_existing=true
    fi

    # Проверка Oh My Zsh
    if [ -d "$USER_HOME/.oh-my-zsh" ]; then
        print_info "Найден: Oh My Zsh"
        has_existing=true
    fi

    # Проверка Powerlevel10k
    if [ -d "$USER_HOME/.powerlevel10k" ]; then
        print_info "Найден: Powerlevel10k"
        has_existing=true
    fi

    # Проверка плагинов
    local plugins_dir="${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}/plugins"
    if [ -d "$plugins_dir" ]; then
        if [ -d "$plugins_dir/zsh-syntax-highlighting" ]; then
            print_info "Найден: zsh-syntax-highlighting"
            has_existing=true
        fi
        if [ -d "$plugins_dir/zsh-autosuggestions" ]; then
            print_info "Найден: zsh-autosuggestions"
            has_existing=true
        fi
    fi

    # Если найдены существующие установки
    if [ "$has_existing" = true ]; then
        echo
        print_info "Обнаружены существующие установки. Выберите действие:"
        echo "      1) Удалить существующие установки и продолжить"
        echo "      2) Отменить установку"
        
        while true; do
            read -r choice
            case $choice in
                1)
                    remove_existing_installation "$USER_HOME"
                    return $?
                    ;;
                2)
                    print_info "Установка отменена"
                    exit 0
                    ;;
                *)
                    print_error "Введите 1 или 2"
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
    
    print_step "Удаление существующих установок"
    
    # Возврат к bash если текущая оболочка zsh
    if [[ "$current_shell" == *"zsh"* ]]; then
        print_info "Смена оболочки на bash..."
        if ! chsh -s $(which bash) $(whoami); then
            print_error "Ошибка при смене оболочки на bash"
            return 1
        fi
    fi

    # Удаление Oh My Zsh
    if [ -d "$USER_HOME/.oh-my-zsh" ]; then
        print_info "Удаление Oh My Zsh..."
        rm -rf "$USER_HOME/.oh-my-zsh" 2>/dev/null || sudo rm -rf "$USER_HOME/.oh-my-zsh"
    fi

    # Удаление Powerlevel10k
    if [ -d "$USER_HOME/.powerlevel10k" ]; then
        print_info "Удаление Powerlevel10k..."
        rm -rf "$USER_HOME/.powerlevel10k" 2>/dev/null || sudo rm -rf "$USER_HOME/.powerlevel10k"
    fi

    # Удаление конфигурационных файлов
    print_info "Удаление конфигурационных файлов..."
    rm -f "$USER_HOME/.zshrc" "$USER_HOME/.zsh_history" "$USER_HOME/.zcompdump"* "$USER_HOME/.p10k.zsh" 2>/dev/null

    # Удаление плагинов
    local plugins_dir="${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}/plugins"
    if [ -d "$plugins_dir" ]; then
        print_info "Удаление плагинов..."
        rm -rf "$plugins_dir/zsh-syntax-highlighting" "$plugins_dir/zsh-autosuggestions" 2>/dev/null || \
        sudo rm -rf "$plugins_dir/zsh-syntax-highlighting" "$plugins_dir/zsh-autosuggestions"
    fi

    print_success "Удаление завершено"
    return 0
}

# Функция установки
install_zsh() {
    local USER_HOME="$1"
    local INSTALL_TYPE="$2"

    print_step "Установка Oh My Zsh"
    if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
        [ -f "$USER_HOME/.zshrc" ] && mv "$USER_HOME/.zshrc" "$USER_HOME/.zshrc.pre-oh-my-zsh"
        print_info "Загрузка и установка Oh My Zsh..."
        if run_with_spinner "Установка Oh My Zsh" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
            print_success "Oh My Zsh установлен"
        else
            print_error "Ошибка при установке Oh My Zsh"
            exit 1
        fi
    fi

    print_step "Установка плагинов"
    local plugins_dir="${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}/plugins"
    mkdir -p "$plugins_dir"
    
    local total_plugins=4
    local current_plugin=0
    
    print_info "Установка плагинов..."
    if [ ! -d "$plugins_dir/zsh-syntax-highlighting" ]; then
        ((current_plugin++))
        progress_bar $current_plugin $total_plugins "Установка плагинов"
        if run_with_spinner "zsh-syntax-highlighting" git clone -q https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugins_dir/zsh-syntax-highlighting"; then
            print_success "zsh-syntax-highlighting установлен"
        else
            print_error "Ошибка при установке zsh-syntax-highlighting"
        fi
    fi
    
    if [ ! -d "$plugins_dir/zsh-autosuggestions" ]; then
        ((current_plugin++))
        progress_bar $current_plugin $total_plugins "Установка плагинов"
        if run_with_spinner "zsh-autosuggestions" git clone -q https://github.com/zsh-users/zsh-autosuggestions.git "$plugins_dir/zsh-autosuggestions"; then
            print_success "zsh-autosuggestions установлен"
        else
            print_error "Ошибка при установке zsh-autosuggestions"
        fi
    fi
    
    if [ ! -d "$USER_HOME/.powerlevel10k" ]; then
        ((current_plugin++))
        progress_bar $current_plugin $total_plugins "Установка плагинов"
        if run_with_spinner "powerlevel10k" git clone -q --depth=1 https://github.com/romkatv/powerlevel10k.git "$USER_HOME/.powerlevel10k"; then
            print_success "powerlevel10k установлен"
        else
            print_error "Ошибка при установке powerlevel10k"
        fi
    fi

    # Установка fzf
    if [ ! -d "$USER_HOME/.fzf" ]; then
        ((current_plugin++))
        progress_bar $current_plugin $total_plugins "Установка плагинов"
        if run_with_spinner "Установка fzf" git clone -q --depth 1 https://github.com/junegunn/fzf.git "$USER_HOME/.fzf"; then
            if run_with_spinner "Настройка fzf" "$USER_HOME/.fzf/install" --all; then
                print_success "fzf установлен"
            else
                print_error "Ошибка при установке fzf"
            fi
        else
            print_error "Ошибка при клонировании fzf"
        fi
    fi

    print_step "Установка пользовательской конфигурации"
    
    # Создаем временную директорию и клонируем репозиторий
    TEMP_DIR=$(mktemp -d)
    print_info "Клонирование репозитория конфигурации..."

    # Проверяем доступность репозитория
    if ! ssh -T git@github.com &>/dev/null; then
        print_error "Нет доступа к GitHub через SSH. Проверьте ваши SSH ключи"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    if run_with_spinner "Клонирование конфигурации" git clone git@github.com:DarthSadist/my_zsh.git "$TEMP_DIR"; then
        print_info "Проверка структуры репозитория..."
        
        # Проверяем содержимое клонированного репозитория
        if [ ! -d "$TEMP_DIR" ]; then
            print_error "Ошибка: директория репозитория не создана"
            exit 1
        fi

        # Выводим содержимое для отладки
        ls -la "$TEMP_DIR"

        # Копируем конфигурационный файл и добавляем настройку FZF_BASE
        if [ -f "$TEMP_DIR/.zshrc" ]; then
            print_info "Найден файл конфигурации, устанавливаем..."
            if run_with_spinner "Установка конфигурации" cp "$TEMP_DIR/.zshrc" "$USER_HOME/.zshrc"; then
                echo -e "\n# fzf configuration\nexport FZF_BASE=$USER_HOME/.fzf" >> "$USER_HOME/.zshrc"
                print_success "Конфигурационный файл установлен и настроен"
            else
                print_error "Ошибка при копировании конфигурационного файла"
                rm -rf "$TEMP_DIR"
                exit 1
            fi
        else
            print_error "Файл .zshrc не найден в репозитории"
            print_info "Содержимое репозитория:"
            ls -la "$TEMP_DIR"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    else
        print_error "Ошибка при клонировании репозитория с конфигурацией"
        print_info "Проверьте доступность репозитория: git@github.com:DarthSadist/my_zsh.git"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Очищаем временную директорию
    rm -rf "$TEMP_DIR"

    # Установка прав на файлы
    chown -R $(whoami):$(whoami) "$USER_HOME/.oh-my-zsh" "$USER_HOME/.zshrc" "$USER_HOME/.powerlevel10k" 2>/dev/null

    echo
    print_success "Установка успешно завершена!"
    echo
    print_info "Для завершения настройки:"
    echo "      1. Закройте текущий терминал"
    echo "      2. Откройте новый терминал"
    echo "      3. Выполните команду: p10k configure"
    echo
}

# Основная функция
main() {
    clear
    echo "╭───────────────────────────────────╮"
    echo "│     Установка Zsh и Oh My Zsh     │"
    echo "╰───────────────────────────────────╯"
    echo
    print_info "Выберите вариант установки:"
    echo "      1) Установка для текущего пользователя"
    echo "      2) Установка для root"
    echo "      3) Отмена установки"
    echo
    
    while true; do
        read -r choice
        case $choice in
            1)
                install_zsh "$HOME" "user"
                break
                ;;
            2)
                if [ "$EUID" -ne 0 ]; then
                    print_error "Для установки root требуются права администратора"
                    exit 1
                fi
                install_zsh "/root" "root"
                break
                ;;
            3)
                print_info "Установка отменена"
                exit 0
                ;;
            *)
                print_error "Введите 1, 2 или 3"
                ;;
        esac
    done
}

main
