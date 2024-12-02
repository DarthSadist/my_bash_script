#!/bin/bash

# Цвета для вывода
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# Константы
readonly OH_MY_ZSH_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
readonly ZSH_SYNTAX_HIGHLIGHTING_URL="https://github.com/zsh-users/zsh-syntax-highlighting.git"
readonly ZSH_AUTOSUGGESTIONS_URL="https://github.com/zsh-users/zsh-autosuggestions.git"
readonly POWERLEVEL10K_URL="https://github.com/romkatv/powerlevel10k.git"
readonly FZF_URL="https://github.com/junegunn/fzf.git"
readonly CONFIG_REPO_URL="git@github.com:DarthSadist/my_zsh.git"

# Функции для форматированного вывода
print_step() {
    echo -e "\n📦 ${BOLD}$1${NC}"
}

print_info() {
    echo -e "   ℹ️  $1"
}

print_success() {
    echo -e "   ✅ ${GREEN}$1${NC}"
}

print_error() {
    echo -e "   ❌ ${RED}$1${NC}"
}

print_warning() {
    echo -e "   ⚠️  ${YELLOW}$1${NC}"
}

# Функция для отображения спиннера
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "   ${BLUE}%c${NC}  " "$spinstr"
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
        echo -e "\r   ✅ ${GREEN}$message${NC}"
        return 0
    else
        echo -e "\r   ❌ ${RED}$message${NC}"
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
    
    printf "\r   📊 ${BOLD}%s${NC} [" "$title"
    printf "%${completed}s" | tr ' ' '█'
    printf "%${remaining}s" | tr ' ' '░'
    printf "] %d%%" "$percentage"
    
    if [ "$current" -eq "$total" ]; then
        echo
    fi
}

# Функция для проверки зависимостей
check_dependencies() {
    local missing_deps=()
    local deps=("git" "curl" "zsh")

    print_step "Проверка зависимостей"
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Отсутствуют необходимые зависимости:"
        for dep in "${missing_deps[@]}"; do
            echo "      - $dep"
        done
        print_info "Установите их с помощью:"
        echo "      sudo apt-get update && sudo apt-get install ${missing_deps[*]}"
        return 1
    fi

    print_success "Все зависимости установлены"
    return 0
}

# Функция для проверки доступа к GitHub
check_github_access() {
    print_info "Проверка доступа к GitHub..."
    if ! ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        print_error "Нет доступа к GitHub через SSH"
        print_info "Для настройки SSH выполните:"
        echo "      1. ssh-keygen -t ed25519 -C \"your_email@example.com\""
        echo "      2. eval \"\$(ssh-agent -s)\""
        echo "      3. ssh-add ~/.ssh/id_ed25519"
        echo "      4. cat ~/.ssh/id_ed25519.pub # Добавьте ключ на GitHub"
        return 1
    fi
    print_success "Доступ к GitHub подтвержден"
    return 0
}

# Функция проверки существующих установок
check_existing_installation() {
    local USER_HOME="$1"
    
    print_step "Проверка существующих установок"
    
    if [ -d "$USER_HOME/.oh-my-zsh" ] || [ -f "$USER_HOME/.zshrc" ]; then
        print_warning "Обнаружена существующая установка Oh-My-Zsh"
        echo "Выберите действие:"
        echo "      1) Удалить существующую установку и продолжить"
        echo "      2) Отменить установку"
        
        while true; do
            read -r choice
            case $choice in
                1)
                    if ! remove_existing_installation "$USER_HOME"; then
                        print_error "Не удалось удалить существующую установку"
                        return 1
                    fi
                    return 0
                    ;;
                2)
                    print_info "Установка отменена"
                    exit 0
                    ;;
                *)
                    print_error "Пожалуйста, введите 1 или 2"
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

    local components=(
        "$USER_HOME/.oh-my-zsh"
        "$USER_HOME/.powerlevel10k"
        "$USER_HOME/.zshrc"
        "$USER_HOME/.zsh_history"
        "$USER_HOME/.zcompdump*"
        "$USER_HOME/.p10k.zsh"
        "$USER_HOME/.fzf"
        "${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
        "${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    )

    for component in "${components[@]}"; do
        if [ -e "$component" ]; then
            print_info "Удаление: $(basename "$component")..."
            rm -rf "$component" 2>/dev/null || sudo rm -rf "$component"
        fi
    done

    print_success "Удаление завершено"
    return 0
}

# Функция установки плагина
install_plugin() {
    local name=$1
    local url=$2
    local install_path=$3
    local current=$4
    local total=$5

    progress_bar $current $total "Установка плагинов"
    if run_with_spinner "$name" git clone -q "$url" "$install_path"; then
        print_success "$name установлен"
        return 0
    else
        print_error "Ошибка при установке $name"
        return 1
    fi
}

# Функция установки
install_zsh() {
    local USER_HOME="$1"

    print_step "Установка Oh My Zsh"
    if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
        [ -f "$USER_HOME/.zshrc" ] && mv "$USER_HOME/.zshrc" "$USER_HOME/.zshrc.pre-oh-my-zsh"
        print_info "Загрузка и установка Oh My Zsh..."
        if run_with_spinner "Установка Oh My Zsh" sh -c "$(curl -fsSL $OH_MY_ZSH_INSTALL_URL)" "" --unattended; then
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

    # Установка zsh-syntax-highlighting
    if [ ! -d "$plugins_dir/zsh-syntax-highlighting" ]; then
        ((current_plugin++))
        install_plugin "zsh-syntax-highlighting" "$ZSH_SYNTAX_HIGHLIGHTING_URL" "$plugins_dir/zsh-syntax-highlighting" $current_plugin $total_plugins
    fi
    
    # Установка zsh-autosuggestions
    if [ ! -d "$plugins_dir/zsh-autosuggestions" ]; then
        ((current_plugin++))
        install_plugin "zsh-autosuggestions" "$ZSH_AUTOSUGGESTIONS_URL" "$plugins_dir/zsh-autosuggestions" $current_plugin $total_plugins
    fi
    
    # Установка powerlevel10k
    if [ ! -d "$USER_HOME/.powerlevel10k" ]; then
        ((current_plugin++))
        install_plugin "powerlevel10k" "$POWERLEVEL10K_URL" "$USER_HOME/.powerlevel10k" $current_plugin $total_plugins
    fi

    # Установка fzf
    if [ ! -d "$USER_HOME/.fzf" ]; then
        ((current_plugin++))
        progress_bar $current_plugin $total_plugins "Установка плагинов"
        if run_with_spinner "Установка fzf" git clone -q --depth 1 "$FZF_URL" "$USER_HOME/.fzf"; then
            if run_with_spinner "Настройка fzf" "$USER_HOME/.fzf/install" --all; then
                print_success "fzf установлен"
            else
                print_error "Ошибка при установке fzf"
            fi
        else
            print_error "Ошибка при клонировании fzf"
        fi
    fi

    install_config "$USER_HOME"
}

# Функция установки конфигурации
install_config() {
    local USER_HOME="$1"
    
    print_step "Установка пользовательской конфигурации"
    
    # Создаем временную директорию и клонируем репозиторий
    TEMP_DIR=$(mktemp -d)
    print_info "Клонирование репозитория конфигурации..."

    if run_with_spinner "Клонирование конфигурации" git clone "$CONFIG_REPO_URL" "$TEMP_DIR"; then
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
        print_info "Проверьте доступность репозитория: $CONFIG_REPO_URL"
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
                check_dependencies
                if [ $? -eq 0 ]; then
                    check_github_access
                    if [ $? -eq 0 ]; then
                        check_existing_installation "$HOME"
                        if [ $? -eq 0 ]; then
                            install_zsh "$HOME" "user"
                        fi
                    fi
                fi
                break
                ;;
            2)
                if [ "$EUID" -ne 0 ]; then
                    print_error "Для установки root требуются права администратора"
                    exit 1
                fi
                check_dependencies
                if [ $? -eq 0 ]; then
                    check_github_access
                    if [ $? -eq 0 ]; then
                        check_existing_installation "/root"
                        if [ $? -eq 0 ]; then
                            install_zsh "/root" "root"
                        fi
                    fi
                fi
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

# Запуск скрипта
main
