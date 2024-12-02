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

# Функция отображения прогресса
progress_bar() {
    local current=$1
    local total=$2
    local prefix=$3
    local width=30
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    printf "\r%s [" "$prefix"
    printf "%${completed}s" | tr ' ' '='
    printf "%${remaining}s" | tr ' ' ' '
    printf "] %3d%%" "$percentage"
    
    if [ "$current" -eq "$total" ]; then
        echo
    fi
}

# Функция запуска команды со спиннером
run_with_spinner() {
    local message=$1
    shift
    local spinner=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
    local pid
    
    printf "   🔄 %s " "$message"
    ("$@") &
    pid=$!
    
    local i=0
    while kill -0 $pid 2>/dev/null; do
        printf "\b%s" "${spinner[i]}"
        i=$(((i + 1) % ${#spinner[@]}))
        sleep 0.1
    done
    
    wait $pid
    local status=$?
    printf "\b "
    if [ $status -eq 0 ]; then
        echo "✅"
        return 0
    else
        echo "❌"
        return 1
    fi
}

# Функция проверки зависимостей
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

# Функция проверки доступа к GitHub
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

# Функция для повторной попытки git clone
retry_git_clone() {
    local repo_url=$1
    local target_dir=$2
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if git clone --depth=1 "$repo_url" "$target_dir" 2>/dev/null; then
            return 0
        fi
        print_warning "Попытка $attempt из $max_attempts не удалась. Повторная попытка..."
        rm -rf "$target_dir"  # Очищаем директорию перед следующей попыткой
        ((attempt++))
        sleep 2
    done
    return 1
}

# Функция установки плагина
install_plugin() {
    local plugin_name=$1
    local plugin_url=$2
    local install_dir=$3

    if [ -d "$install_dir" ]; then
        rm -rf "$install_dir"
    fi

    if retry_git_clone "$plugin_url" "$install_dir"; then
        print_success "$plugin_name установлен успешно"
        return 0
    else
        print_error "Не удалось установить $plugin_name после нескольких попыток"
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
        install_plugin "zsh-syntax-highlighting" "$ZSH_SYNTAX_HIGHLIGHTING_URL" "$plugins_dir/zsh-syntax-highlighting"
    fi
    
    # Установка zsh-autosuggestions
    if [ ! -d "$plugins_dir/zsh-autosuggestions" ]; then
        ((current_plugin++))
        install_plugin "zsh-autosuggestions" "$ZSH_AUTOSUGGESTIONS_URL" "$plugins_dir/zsh-autosuggestions"
    fi
    
    # Установка powerlevel10k
    if [ ! -d "$USER_HOME/.powerlevel10k" ]; then
        ((current_plugin++))
        install_plugin "powerlevel10k" "$POWERLEVEL10K_URL" "$USER_HOME/.powerlevel10k"
    fi

    # Установка fzf
    if [ ! -d "$USER_HOME/.fzf" ]; then
        ((current_plugin++))
        if run_with_spinner "Установка fzf" git clone --depth 1 "$FZF_URL" "$USER_HOME/.fzf"; then
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

# Функция проверки версий
check_versions() {
    local USER_HOME="$1"
    print_step "Проверка версий компонентов"
    
    # Проверка версии zsh
    if command -v zsh >/dev/null 2>&1; then
        local zsh_version=$(zsh --version | cut -d' ' -f2)
        print_info "Версия Zsh: $zsh_version"
    fi
    
    # Проверка версии oh-my-zsh
    if [ -d "$USER_HOME/.oh-my-zsh" ]; then
        if [ -f "$USER_HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
            local omz_version=$(grep 'OMZVERSION=' "$USER_HOME/.oh-my-zsh/oh-my-zsh.sh" | cut -d'"' -f2)
            print_info "Версия Oh My Zsh: $omz_version"
        fi
    fi
    
    # Проверка версии powerlevel10k
    if [ -d "$USER_HOME/.powerlevel10k" ]; then
        cd "$USER_HOME/.powerlevel10k" || return
        local p10k_version=$(git describe --tags --abbrev=0 2>/dev/null)
        print_info "Версия Powerlevel10k: $p10k_version"
        cd - >/dev/null || return
    fi
}

# Функция обновления компонентов
update_components() {
    local USER_HOME="$1"
    print_step "Обновление компонентов"
    
    # Обновление oh-my-zsh
    if [ -d "$USER_HOME/.oh-my-zsh" ]; then
        print_info "Обновление Oh My Zsh..."
        if run_with_spinner "Обновление Oh My Zsh" env ZSH="$USER_HOME/.oh-my-zsh" sh "$USER_HOME/.oh-my-zsh/tools/upgrade.sh"; then
            print_success "Oh My Zsh обновлен"
        else
            print_error "Ошибка при обновлении Oh My Zsh"
        fi
    fi
    
    # Обновление powerlevel10k
    if [ -d "$USER_HOME/.powerlevel10k" ]; then
        print_info "Обновление Powerlevel10k..."
        cd "$USER_HOME/.powerlevel10k" || return
        if run_with_spinner "Обновление Powerlevel10k" git pull --quiet; then
            print_success "Powerlevel10k обновлен"
        else
            print_error "Ошибка при обновлении Powerlevel10k"
        fi
        cd - >/dev/null || return
    fi
    
    # Обновление плагинов
    local plugins_dir="${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}/plugins"
    
    if [ -d "$plugins_dir/zsh-syntax-highlighting" ]; then
        print_info "Обновление zsh-syntax-highlighting..."
        cd "$plugins_dir/zsh-syntax-highlighting" || return
        if run_with_spinner "Обновление zsh-syntax-highlighting" git pull --quiet; then
            print_success "zsh-syntax-highlighting обновлен"
        else
            print_error "Ошибка при обновлении zsh-syntax-highlighting"
        fi
        cd - >/dev/null || return
    fi
    
    if [ -d "$plugins_dir/zsh-autosuggestions" ]; then
        print_info "Обновление zsh-autosuggestions..."
        cd "$plugins_dir/zsh-autosuggestions" || return
        if run_with_spinner "Обновление zsh-autosuggestions" git pull --quiet; then
            print_success "zsh-autosuggestions обновлен"
        else
            print_error "Ошибка при обновлении zsh-autosuggestions"
        fi
        cd - >/dev/null || return
    fi
    
    # Обновление fzf
    if [ -d "$USER_HOME/.fzf" ]; then
        print_info "Обновление fzf..."
        cd "$USER_HOME/.fzf" || return
        if run_with_spinner "Обновление fzf" git pull --quiet; then
            if run_with_spinner "Переустановка fzf" ./install --all; then
                print_success "fzf обновлен"
            else
                print_error "Ошибка при переустановке fzf"
            fi
        else
            print_error "Ошибка при обновлении fzf"
        fi
        cd - >/dev/null || return
    fi
}

# Основная функция
main() {
    clear
    echo "╭───────────────────────────────────╮"
    echo "│     Установка Zsh и Oh My Zsh     │"
    echo "╰───────────────────────────────────╯"
    echo
    print_info "Выберите действие:"
    echo "      1) Установка для текущего пользователя"
    echo "      2) Установка для root"
    echo "      3) Проверка версий компонентов"
    echo "      4) Обновление компонентов"
    echo "      5) Отмена"
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
                            install_zsh "$HOME"
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
                            install_zsh "/root"
                        fi
                    fi
                fi
                break
                ;;
            3)
                check_versions "$HOME"
                break
                ;;
            4)
                update_components "$HOME"
                break
                ;;
            5)
                print_info "Операция отменена"
                exit 0
                ;;
            *)
                print_error "Введите число от 1 до 5"
                ;;
        esac
    done
}

# Запуск скрипта
main
