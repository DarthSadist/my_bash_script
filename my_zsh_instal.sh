#!/bin/bash

# Версия скрипта
VERSION="1.0.0"

# Определение цветов для вывода
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Настройки по умолчанию
INTERACTIVE=false
MAKE_BACKUP=true
DEBUG=false
QUIET=false
CONFIGURE_VIM=false
CONFIGURE_TMUX=false

# Глобальные переменные для хранения выбранных настроек
SELECTED_THEME="robbyrussell"
SELECTED_PLUGINS="git zsh-syntax-highlighting zsh-autosuggestions history-substring-search"
INSTALLED_FONT=""
INSTALLED_TOOLS=""
EXPORT_SETTINGS=false
IMPORT_SETTINGS=false
IMPORT_FILE=""
CHECK_CONFIG=false
CREATE_CHEATSHEET=false
INSTALL_ALL=false

# Функция для вывода справки
print_help() {
    echo -e "${BOLD}Установщик Zsh с Oh My Zsh и дополнениями v${VERSION}${NC}"
    echo -e "Использование: $0 [опции]"
    echo -e ""
    echo -e "Основные опции:"
    echo -e "  -h, --help         Показать эту справку и выйти"
    echo -e "  -v, --version      Показать версию и выйти"
    echo -e "  -i, --interactive  Запустить в интерактивном режиме"
    echo -e "  --no-backup        Не создавать резервные копии существующих файлов"
    echo -e "  -d, --debug        Включить режим отладки (подробный вывод)"
    echo -e "  -q, --quiet        Тихий режим (минимальный вывод)"
    echo -e ""
    echo -e "Дополнительные опции:"
    echo -e "  --export           Экспортировать настройки в архив"
    echo -e "  --import [FILE]    Импортировать настройки из архива (FILE необязательно)"
    echo -e "  --vim              Установить и настроить Vim"
    echo -e "  --tmux             Установить и настроить Tmux"
    echo -e "  --check            Проверить текущую конфигурацию"
    echo -e "  --cheatsheet       Создать шпаргалку по использованию Zsh"
    echo -e "  --all              Автоматическая установка всех компонентов (без вопросов)"
    echo -e ""
    echo -e "Примеры:"
    echo -e "  $0                 Установить Zsh и Oh My Zsh"
    echo -e "  $0 -i              Установить в интерактивном режиме"
    echo -e "  $0 --export        Экспортировать текущие настройки"
    echo -e "  $0 --import        Импортировать настройки"
    echo -e "  $0 -i --vim --tmux Установить с Vim и Tmux в интерактивном режиме"
    exit 0
}

# Функция для вывода версии
print_version() {
    echo -e "Установщик Zsh v${VERSION}"
    exit 0
}

# Переменные для экспорта/импорта определены в начале файла

# Обработка аргументов командной строки
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            print_help
            ;;
        -v|--version)
            print_version
            ;;
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        --no-backup)
            MAKE_BACKUP=false
            shift
            ;;
        -d|--debug)
            DEBUG=true
            # Включаем подробный вывод для bash
            set -x
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        --export)
            EXPORT_SETTINGS=true
            shift
            ;;
        --import)
            IMPORT_SETTINGS=true
            if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
                IMPORT_FILE="$2"
                shift
            fi
            shift
            ;;
        --vim)
            CONFIGURE_VIM=true
            shift
            ;;
        --tmux)
            CONFIGURE_TMUX=true
            shift
            ;;
        --check)
            CHECK_CONFIG=true
            shift
            ;;
        --cheatsheet)
            CREATE_CHEATSHEET=true
            shift
            ;;
        --all)
            INSTALL_ALL=true
            shift
            ;;
        *)
            echo -e "${RED}Ошибка:${NC} Неизвестный параметр '$1'"
            echo -e "Используйте '$0 --help' для получения справки"
            exit 1
            ;;
    esac
done

# Функция для логирования и вывода сообщений
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Если режим дебага отключен, не выводим отладочные сообщения
    if [ "$level" = "DEBUG" ] && [ "$DEBUG" = false ]; then
        return
    fi
    
    # Если режим тихий, выводим только ошибки
    if [ "$QUIET" = true ] && [ "$level" != "ERROR" ]; then
        return
    fi

    case "$level" in
        INFO)
            echo -e "${BLUE}[*]${NC} $message"
            ;;
        SUCCESS)
            echo -e "${GREEN}[✔]${NC} $message"
            ;;
        WARNING)
            echo -e "${YELLOW}[!]${NC} $message"
            ;;
        ERROR)
            echo -e "${RED}[✘]${NC} $message"
            ;;
        DEBUG)
            echo -e "${BLUE}[D]${NC} $message"
            ;;
        HEADER)
            echo -e "\n${BOLD}$message${NC}"
            echo -e "${BOLD}$(printf '%.0s-' {1..50})${NC}\n"
            ;;
    esac
    
    # Запись в журнал, если нужно
    if [ "$DEBUG" = true ]; then
        echo "[$timestamp] [$level] $message" >> "$HOME/.zsh_install.log"
    fi
}

# Функции для удобства вызова
print_status() {
    log "INFO" "$1"
}

print_success() {
    log "SUCCESS" "$1"
}

print_warning() {
    log "WARNING" "$1"
}

print_error() {
    log "ERROR" "$1"
}

print_debug() {
    log "DEBUG" "$1"
}

print_info() {
    log "INFO" "$1"
}

print_header() {
    log "HEADER" "$1"
}

# Обработка прерываний и ошибок
cleanup() {
    print_warning "Установка прервана. Удаление временных файлов..."
    # Удаляем все временные файлы
    rm -f install.sh 2>/dev/null
    print_warning "Завершение работы скрипта."
    exit 1
}

# Устанавливаем trap для обработки сигналов
trap cleanup SIGINT SIGTERM

# Функция для создания резервных копий
backup_file() {
    if [ "$MAKE_BACKUP" = false ]; then
        print_debug "Создание резервных копий отключено"
        return
    fi
    
    local file_path=$1
    local backup_dir="$HOME/.zsh_backups"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    
    if [ ! -f "$file_path" ]; then
        print_debug "Файл $file_path не существует, резервная копия не требуется"
        return
    fi
    
    # Создаем директорию для резервных копий, если она не существует
    mkdir -p "$backup_dir"
    
    # Копируем файл с временной меткой
    local filename=$(basename "$file_path")
    cp "$file_path" "$backup_dir/${filename}.${timestamp}.bak"
    
    print_debug "Создана резервная копия $file_path -> $backup_dir/${filename}.${timestamp}.bak"
}

# Проверяем, установлен ли уже Zsh
if ! command -v zsh &>/dev/null; then
    print_error "Zsh не установлен. Пожалуйста, установите его с помощью менеджера пакетов:"
    echo "sudo apt install zsh"
    exit 1
fi

print_success "Zsh уже установлен"

# Функция для проверки и удаления существующей установки
check_and_remove_existing() {
    print_header "Очистка предыдущей установки"
    
    local items_to_check=(
        "$HOME/.oh-my-zsh"
        "$HOME/.powerlevel10k"
        "$HOME/.zshrc"
        "$HOME/.zsh_history"
        "$HOME/.p10k.zsh"
        "$HOME/.zlogin"
        "$HOME/.zlogout"
        "$HOME/.zprofile"
        "$HOME/.zshenv"
        "$HOME/my_zsh"
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    )
    
    if [ "$INTERACTIVE" = true ]; then
        print_status "Существующие компоненты Zsh, которые могут быть удалены:"
        
        local found=false
        for item in "${items_to_check[@]}"; do
            if [ -e "$item" ]; then
                echo -e "  - $item"
                found=true
            fi
        done
        
        if [ "$found" = false ]; then
            print_success "Предыдущих установок не обнаружено"
            return
        fi
        
        local choice
        read -p "Удалить предыдущие установки? (да/нет) [yes/no]: " choice
        case "$choice" in
            [Yy]|[Yy][Ee][Ss]|[Dd][Aa]|да|Да|ДА)
                print_success "Продолжаем удаление предыдущих установок..."
                ;;
            *)
                print_warning "Установка прервана пользователем"
                exit 0
                ;;
        esac
    fi
    
    # Проверка и удаление Oh My Zsh
    if [ -d "$HOME/.oh-my-zsh" ]; then
        print_status "Удаление Oh My Zsh..."
        create_backup "$HOME/.oh-my-zsh"
        rm -rf "$HOME/.oh-my-zsh" &>/dev/null
        print_debug "Oh My Zsh удален"
    fi

    # Проверка и удаление Powerlevel10k
    if [ -d "$HOME/.powerlevel10k" ]; then
        print_status "Удаление Powerlevel10k..."
        create_backup "$HOME/.powerlevel10k"
        rm -rf "$HOME/.powerlevel10k" &>/dev/null
        print_debug "Powerlevel10k удален"
    fi

    # Проверка и удаление конфигурационных файлов
    local config_files=(
        "$HOME/.zshrc"
        "$HOME/.zsh_history"
        "$HOME/.p10k.zsh"
        "$HOME/.zlogin"
        "$HOME/.zlogout"
        "$HOME/.zprofile"
        "$HOME/.zshenv"
    )
    
    for config_file in "${config_files[@]}"; do
        if [ -f "$config_file" ]; then
            print_status "Удаление $(basename "$config_file")..."
            create_backup "$config_file"
            rm -f "$config_file" &>/dev/null
            print_debug "$(basename "$config_file") удален"
        fi
    done

    # Удаление папки my_zsh если она существует
    if [ -d "$HOME/my_zsh" ]; then
        print_status "Удаление папки my_zsh..."
        create_backup "$HOME/my_zsh"
        rm -rf "$HOME/my_zsh" &>/dev/null
        print_debug "my_zsh удален"
    fi
    
    # Удаление плагинов
    local plugins_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    local plugins=("zsh-syntax-highlighting" "zsh-autosuggestions")
    
    for plugin in "${plugins[@]}"; do
        if [ -d "$plugins_dir/$plugin" ]; then
            print_status "Удаление плагина $plugin..."
            rm -rf "$plugins_dir/$plugin" &>/dev/null
            print_debug "Плагин $plugin удален"
        fi
    done

    print_success "Очистка завершена"
}

# Определение дистрибутива Linux
get_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo $ID
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        echo $DISTRIB_ID
    else
        echo "unknown"
    fi
}

# Функция для проверки и установки пакетов
install_package() {
    local package_name=$1
    local force_install=${2:-false}
    
    # Проверяем, есть ли необходимость в установке
    if ! command -v $package_name &> /dev/null || [ "$force_install" = true ]; then
        print_status "Установка $package_name..."
        
        # Получаем информацию о дистрибутиве
        local distro=$(get_distro)
        print_debug "Определен дистрибутив: $distro"
        
        # Выбираем команду для установки в зависимости от дистрибутива
        case "$distro" in
            ubuntu|debian|pop|mint|linuxmint)
                if [ "$QUIET" = true ]; then
                    sudo apt install -y $package_name &>/dev/null
                else
                    sudo apt install -y $package_name
                fi
                ;;
            fedora)
                if [ "$QUIET" = true ]; then
                    sudo dnf install -y $package_name &>/dev/null
                else
                    sudo dnf install -y $package_name
                fi
                ;;
            centos|rhel)
                if [ "$QUIET" = true ]; then
                    sudo yum install -y $package_name &>/dev/null
                else
                    sudo yum install -y $package_name
                fi
                ;;
            arch|manjaro|endeavouros)
                if [ "$QUIET" = true ]; then
                    sudo pacman -S --noconfirm $package_name &>/dev/null
                else
                    sudo pacman -S --noconfirm $package_name
                fi
                ;;
            opensuse*)
                if [ "$QUIET" = true ]; then
                    sudo zypper install -y $package_name &>/dev/null
                else
                    sudo zypper install -y $package_name
                fi
                ;;
            *)
                # По умолчанию пробуем apt
                print_warning "Неизвестный дистрибутив: $distro. Пробуем apt."
                if [ "$QUIET" = true ]; then
                    sudo apt install -y $package_name &>/dev/null
                else
                    sudo apt install -y $package_name
                fi
                ;;
        esac
        
        # Проверяем успешность установки
        check_success "$package_name установлен" "Ошибка установки $package_name"
    else
        print_debug "$package_name уже установлен"
    fi
}

# Функция для проверки успешности выполнения команды
check_success() {
    local exit_code=$?
    local success_msg=$1
    local error_msg=$2
    local exit_on_error=${3:-true}  # По умолчанию выходим при ошибке
    
    if [ $exit_code -eq 0 ]; then
        print_success "$success_msg"
        return 0
    else
        print_error "$error_msg (код ошибки: $exit_code)"
        if [ "$exit_on_error" = true ]; then
            print_error "Завершение работы из-за ошибки."
            exit 1
        fi
        return 1
    fi
}

# Функция для проверки наличия доступа в интернет
check_internet_connection() {
    print_status "Проверка подключения к интернету..."
    if ping -c 1 github.com &>/dev/null || ping -c 1 google.com &>/dev/null; then
        print_success "Подключение к интернету установлено"
        return 0
    else
        print_error "Отсутствует подключение к интернету. Пожалуйста, проверьте соединение."
        exit 1
    fi
}

# Основная функция для проверки и установки необходимых компонентов
main() {
    # Обработка специальных режимов
    if [ "$EXPORT_SETTINGS" = true ]; then
        export_settings
        exit 0
    fi
    
    if [ "$IMPORT_SETTINGS" = true ]; then
        import_settings "$IMPORT_FILE"
        exit 0
    fi
    
    if [ "$CHECK_CONFIG" = true ]; then
        check_configuration
        exit $?
    fi
    
    if [ "$CREATE_CHEATSHEET" = true ]; then
        create_cheatsheet
        exit 0
    fi

    # Если включен режим автоматической установки, устанавливаем все компоненты
    if [ "$INSTALL_ALL" = true ]; then
        CONFIGURE_VIM=true
        CONFIGURE_TMUX=true
        INTERACTIVE=false
        print_header "Автоматическая установка всех компонентов v${VERSION}"
        print_status "Все компоненты будут установлены автоматически без запросов"
        
        # Устанавливаем стандартные значения
        SELECTED_THEME="powerlevel10k/powerlevel10k"
        SELECTED_PLUGINS="git zsh-syntax-highlighting zsh-autosuggestions history-substring-search colored-man-pages sudo fzf autojump command-not-found"
        
        # Добавим базовые инструменты для автоматической установки
        local auto_tools=("curl" "wget" "git" "fzf" "ripgrep" "bat" "fd-find" "jq" "htop" "ncdu")
        local distro=$(get_distro)
        # Подготовимся к автоматической установке
    else
        # Вывод версии скрипта
        print_header "Установщик Zsh с Oh My Zsh и дополнениями v${VERSION}"
    fi
    
    # Проверка подключения к интернету
    check_internet_connection

    # Проверяем, установлен ли уже Zsh
    if ! command -v zsh &>/dev/null; then
        print_warning "Zsh не установлен. Устанавливаем..."
        install_package zsh
    else
        print_success "Zsh уже установлен"
        print_debug "$(zsh --version)"
    fi

    # Запускаем проверку и удаление перед установкой
    check_and_remove_existing

    # Обновление списков пакетов в зависимости от дистрибутива
    print_header "Установка необходимых компонентов"
    print_status "Обновление менеджера пакетов..."
    
    local distro=$(get_distro)
    case "$distro" in
        ubuntu|debian|pop|mint|linuxmint)
            if [ "$QUIET" = true ]; then
                sudo apt update &>/dev/null
            else
                sudo apt update
            fi
            ;;
        fedora)
            if [ "$QUIET" = true ]; then
                sudo dnf check-update &>/dev/null
            else
                sudo dnf check-update
            fi
            ;;
        centos|rhel)
            if [ "$QUIET" = true ]; then
                sudo yum check-update &>/dev/null
            else
                sudo yum check-update
            fi
            ;;
        arch|manjaro|endeavouros)
            if [ "$QUIET" = true ]; then
                sudo pacman -Sy &>/dev/null
            else
                sudo pacman -Sy
            fi
            ;;
        opensuse*)
            if [ "$QUIET" = true ]; then
                sudo zypper refresh &>/dev/null
            else
                sudo zypper refresh
            fi
            ;;
        *)
            # По умолчанию пробуем apt
            print_warning "Неизвестный дистрибутив: $distro. Пробуем apt."
            if [ "$QUIET" = true ]; then
                sudo apt update &>/dev/null || true
            else
                sudo apt update || true
            fi
            ;;
    esac
    check_success "Списки пакетов обновлены" "Ошибка обновления списков пакетов" false  # Не выходим при ошибке

    # Установка необходимых пакетов
    for package in git wget curl; do
        install_package $package
    done
    
    # Установка дополнительных пакетов
    if [ "$INTERACTIVE" = true ]; then
        local choice
        read -p "Установить дополнительные пакеты (fzf, fd-find, ripgrep)? [yes/no]: " choice
        case "$choice" in
            [Yy]|[Yy][Ee][Ss]|[Dd][Aa]|да|Да|ДА)
                for package in fzf fd-find ripgrep; do
                    install_package $package
                done
                ;;
            *)
                print_debug "Установка дополнительных пакетов пропущена"
                ;;
        esac
    else
        # Устанавливаем fzf по умолчанию, даже в неинтерактивном режиме
        install_package fzf
    fi
    # Вызов функций для установки Oh My Zsh
    install_oh_my_zsh
    
    # Установка и настройка темы
    install_zsh_theme
    
    # Установка плагинов
    install_plugins
    
    # Настройка дополнительных инструментов
    if [ "$CONFIGURE_VIM" = true ] || [ "$INTERACTIVE" = true ]; then
        local install_vim=false
        
        if [ "$CONFIGURE_VIM" = true ]; then
            install_vim=true
        elif [ "$INTERACTIVE" = true ]; then
            read -p "Установить и настроить Vim? [yes/no]: " choice
            case "$choice" in
                [Yy]|[Yy][Ee][Ss]|[Dd][Aa]|да|Да|ДА)
                    install_vim=true
                    ;;
            esac
        fi
        
        if [ "$install_vim" = true ]; then
            configure_vim
        fi
    fi
    
    if [ "$CONFIGURE_TMUX" = true ] || [ "$INTERACTIVE" = true ]; then
        local install_tmux=false
        
        if [ "$CONFIGURE_TMUX" = true ]; then
            install_tmux=true
        elif [ "$INTERACTIVE" = true ]; then
            read -p "Установить и настроить Tmux? [yes/no]: " choice
            case "$choice" in
                [Yy]|[Yy][Ee][Ss]|[Dd][Aa]|да|Да|ДА)
                    install_tmux=true
                    ;;
            esac
        fi
        
        if [ "$install_tmux" = true ]; then
            configure_tmux
        fi
    fi
    
    # Установка дополнительных инструментов разработки
    if [ "$INTERACTIVE" = true ]; then
        install_dev_tools
    elif [ "$INSTALL_ALL" = true ]; then
        # Для автоматической установки ставим базовые инструменты
        print_status "Автоматическая установка базовых инструментов разработки"
        for tool in curl wget git fzf ripgrep bat jq htop; do
            install_package "$tool"
        done
        
        # Добавляем установленные инструменты в список
        INSTALLED_TOOLS="curl wget git fzf ripgrep bat jq htop"
        print_success "Базовые инструменты разработки установлены"
    fi
    
    # Настройка Git
    if [ "$INTERACTIVE" = true ]; then
        configure_git
    fi
    
    # Создание конфига и установка Zsh как оболочки по умолчанию
    configure_zsh
    set_zsh_as_default_shell

    # Завершающее сообщение
    print_installation_complete
}

# Функция для установки Oh My Zsh
install_oh_my_zsh() {
    print_header "Установка Oh My Zsh"
    print_status "Установка Oh My Zsh..."
    
    # Загрузка и установка Oh My Zsh
    print_status "Загрузка установщика Oh My Zsh..."
    if ! wget -O install.sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh 2>/dev/null; then
        print_error "Ошибка загрузки установщика Oh My Zsh"
        exit 1
    fi

    print_status "Запуск установщика..."
    chmod +x install.sh
    # Устанавливаем правильные переменные окружения
    export RUNZSH=no
    export ZSH="$HOME/.oh-my-zsh"
    export KEEP_ZSHRC=yes

    # Запускаем установщик от имени текущего пользователя
    if ! bash -c "./install.sh --unattended"; then
        print_error "Ошибка выполнения установщика Oh My Zsh"
        rm -f install.sh
        exit 1
    fi
    rm -f install.sh

    # Проверка установки Oh My Zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        print_error "Директория .oh-my-zsh не создана"
        exit 1
    fi

    if [ ! -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
        print_error "Файл oh-my-zsh.sh не найден"
        exit 1
    fi

    print_success "Oh My Zsh установлен"
}

# Функция для выбора плагинов
select_plugins() {
    print_header "Выбор плагинов"
    
    local all_plugins=(
        "git:Алиасы и утилиты для Git"
        "zsh-syntax-highlighting:Подсветка синтаксиса команд (рекомендуется)"
        "zsh-autosuggestions:Автоподстановка на основе истории (рекомендуется)"
        "history-substring-search:Поиск в истории по подстроке"
        "sudo:Нажмите Alt+S для добавления sudo к команде"
        "docker:Команды и автодополнение для Docker"
        "kubectl:Автодополнение для Kubernetes"
        "copypath:Удобное копирование путей файлов"
        "dirhistory:Навигация по истории директорий"
        "colored-man-pages:Цветной вывод man страниц"
        "command-not-found:Предложения при неверных командах"
        "extract:Распаковка архивов одной командой"
        "z:Быстрая навигация по часто используемым каталогам"
        "fzf:Нечеткий поиск для командной строки"
    )
    
    # Выбранные по умолчанию плагины
    local default_plugins=("git" "zsh-syntax-highlighting" "zsh-autosuggestions" "history-substring-search")
    local selected_plugins=()
    
    echo "Доступные плагины:"
    local i=1
    for plugin_info in "${all_plugins[@]}"; do
        IFS=':' read -r plugin_name plugin_desc <<< "$plugin_info"
        
        # Проверяем, выбран ли плагин по умолчанию
        local is_selected=""
        for default_plugin in "${default_plugins[@]}"; do
            if [ "$default_plugin" = "$plugin_name" ]; then
                is_selected="[X]"
                break
            fi
        done
        
        echo "$i) $is_selected $plugin_name - $plugin_desc"
        ((i++))
    done
    
    echo -e "\nПлагины, отмеченные [X], будут установлены по умолчанию."
    echo "Введите номера плагинов через пробел для выбора."
    echo "Оставьте пустым для использования плагинов по умолчанию."
    
    local choices
    read -p "Выберите плагины: " choices
    
    if [ -z "$choices" ]; then
        # Если ничего не выбрано, используем плагины по умолчанию
        selected_plugins=("${default_plugins[@]}")
    else
        # Обработка выбора пользователя
        for choice in $choices; do
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#all_plugins[@]}" ]; then
                IFS=':' read -r plugin_name _ <<< "${all_plugins[$((choice-1))]}"
                
                # Проверяем, не добавлен ли плагин уже
                local already_added=false
                for selected_plugin in "${selected_plugins[@]}"; do
                    if [ "$selected_plugin" = "$plugin_name" ]; then
                        already_added=true
                        break
                    fi
                done
                
                if [ "$already_added" = false ]; then
                    selected_plugins+=("$plugin_name")
                fi
            fi
        done
    fi
    
    # Если ничего не выбрано, используем плагины по умолчанию
    if [ ${#selected_plugins[@]} -eq 0 ]; then
        selected_plugins=("${default_plugins[@]}")
    fi
    
    # Формируем строку с плагинами
    local result=""
    for plugin in "${selected_plugins[@]}"; do
        result+="$plugin "
    done
    
    # Удаляем завершающий пробел
    echo "${result% }"
}

# Переходная функция
# Эти функции определены позже в скрипте

# Функция установки и настройки плагинов Zsh
install_plugins() {
    print_header "Установка плагинов"
    
    # Список плагинов по умолчанию
    local plugins="git zsh-syntax-highlighting zsh-autosuggestions history-substring-search"
    
    # Если выбран интерактивный режим, предлагаем выбрать плагины
    if [ "$INTERACTIVE" = true ]; then
        plugins=$(select_plugins)
    fi
    
    print_status "Выбранные плагины: $plugins"
    
    # Создаем массив из строки с плагинами
    local plugins_array=()
    for plugin in $plugins; do
        plugins_array+=("$plugin")
    done
    
    # Устанавливаем каждый плагин
    for plugin in "${plugins_array[@]}"; do
        # Стандартные плагины Oh My Zsh не нужно устанавливать
        if [[ "$plugin" != "git" && \
              "$plugin" != "sudo" && \
              "$plugin" != "docker" && \
              "$plugin" != "kubectl" && \
              "$plugin" != "copypath" && \
              "$plugin" != "dirhistory" && \
              "$plugin" != "colored-man-pages" && \
              "$plugin" != "command-not-found" && \
              "$plugin" != "extract" && \
              "$plugin" != "z" && \
              "$plugin" != "fzf" ]]; then
            print_status "Установка плагина $plugin..."
            
            case "$plugin" in
                "zsh-syntax-highlighting")
                    if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
                        git clone -q https://github.com/zsh-users/zsh-syntax-highlighting.git \
                            ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting &>/dev/null
                        check_success "$plugin установлен" "Ошибка установки $plugin"
                    else
                        print_success "$plugin уже установлен"
                    fi
                    ;;
                "zsh-autosuggestions")
                    if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
                        git clone -q https://github.com/zsh-users/zsh-autosuggestions.git \
                            ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions &>/dev/null
                        check_success "$plugin установлен" "Ошибка установки $plugin"
                    else
                        print_success "$plugin уже установлен"
                    fi
                    ;;
                "history-substring-search")
                    # Исправление: плагин называется zsh-history-substring-search, но в конфиге используется как history-substring-search
                    if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search" ]; then
                        git clone -q https://github.com/zsh-users/zsh-history-substring-search.git \
                            ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search &>/dev/null
                        check_success "$plugin установлен" "Ошибка установки $plugin"
                    else
                        print_success "$plugin уже установлен"
                    fi
                    
                    # Создаем символическую ссылку, чтобы плагин работал с обоими названиями
                    if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/history-substring-search" ] && \
                       [ -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search" ]; then
                        ln -sf "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search" \
                              "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/history-substring-search"
                        print_debug "Создана символическая ссылка для плагина history-substring-search"
                    fi
                    ;;
                *)
                    print_warning "Неизвестный плагин: $plugin"
                    ;;
            esac
        else
            print_debug "Плагин $plugin является встроенным, установка не требуется"
        fi
    done
    
    # Сохраняем список плагинов для использования в конфигурации
    SELECTED_PLUGINS="$plugins"
    
    print_success "Все выбранные плагины установлены"
    
    # Установка темы
    install_zsh_theme
}

# Функция для установки шрифтов Nerd Fonts
install_nerd_fonts() {
    print_header "Установка шрифтов Nerd Fonts"
    
    if [ "$INTERACTIVE" = true ]; then
        local choice
        read -p "Установить шрифты Nerd Fonts для оптимальной работы Powerlevel10k? [yes/no]: " choice
        case "$choice" in
            [Yy]|[Yy][Ee][Ss]|[Dd][Aa]|да|Да|ДА)
                # Продолжаем установку
                ;;
            *)
                print_debug "Установка шрифтов Nerd Fonts пропущена"
                return
                ;;
        esac
    fi
    
    # Создаем директорию для шрифтов, если её нет
    local fonts_dir="$HOME/.local/share/fonts"
    mkdir -p "$fonts_dir"
    
    # Проверяем права на запись в директорию
    if [ ! -w "$fonts_dir" ]; then
        print_error "Нет прав на запись в директорию $fonts_dir"
        return 1
    fi
    
    # Выбираем шрифт для установки
    local font_name="Meslo"
    local font_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/Meslo.zip"
    
    if [ "$INTERACTIVE" = true ]; then
        print_status "Доступные шрифты:"
        echo -e "1) Meslo (рекомендуется для Powerlevel10k)"
        echo -e "2) FiraCode"
        echo -e "3) JetBrainsMono"
        echo -e "4) Hack"
        
        local font_choice
        read -p "Выберите шрифт (1-4): " font_choice
        
        case "$font_choice" in
            2)
                font_name="FiraCode"
                font_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/FiraCode.zip"
                ;;
            3)
                font_name="JetBrainsMono"
                font_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip"
                ;;
            4)
                font_name="Hack"
                font_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/Hack.zip"
                ;;
            *)
                # По умолчанию Meslo
                ;;
        esac
    fi
    
    print_status "Загрузка шрифта $font_name..."
    
    # Создаем временную директорию
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # Проверка наличия unzip
    if ! command -v unzip &> /dev/null; then
        print_status "Установка unzip, необходимого для распаковки шрифтов..."
        install_package unzip
    fi
    
    # Загрузка архива шрифта
    if ! wget -q "$font_url" -O "$font_name.zip"; then
        print_error "Не удалось загрузить шрифт $font_name"
        cd - > /dev/null
        rm -rf "$temp_dir"
        return 1
    fi
    
    print_status "Распаковка шрифта..."
    
    # Создаем директорию для шрифта
    local font_target_dir="$fonts_dir/$font_name"
    mkdir -p "$font_target_dir"
    
    # Распаковка шрифта
    if ! unzip -q "$font_name.zip" -d "$font_target_dir"; then
        print_error "Ошибка распаковки шрифта"
        cd - > /dev/null
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Устанавливаем права на файлы
    chmod -R u+r "$font_target_dir"
    
    # Очистка
    cd - > /dev/null
    rm -rf "$temp_dir"
    
    # Обновление кэша шрифтов
    print_status "Обновление кэша шрифтов..."
    if command -v fc-cache &> /dev/null; then
        fc-cache -f
    fi
    
    print_success "Шрифт $font_name успешно установлен"
    print_status "Для использования шрифта установите его в настройках вашего терминала"
    
    # Сохраняем информацию о шрифте для итогового вывода
    INSTALLED_FONT="$font_name"
}

# Функция для выбора темы
select_theme() {
    print_header "Выбор темы оформления"
    
    local themes=(
        "robbyrussell:Классическая тема Oh My Zsh"
        "powerlevel10k/powerlevel10k:Мощная тема с богатой настройкой (рекомендуется)"
        "agnoster:Красивая тема с индикацией Git"
        "af-magic:Минималистичная тема"
        "avit:Чистая элегантная тема"
        "bureau:Современный вид с информацией о Git"
        "eastwood:Минималистичная тема с Git"
        "fishy:Тема в стиле Fish shell"
        "bira:Две строки с Git"
        "dstufft:Минималистичный промпт"
    )
    
    echo "Доступные темы:"
    local i=1
    for theme_info in "${themes[@]}"; do
        IFS=':' read -r theme_name theme_desc <<< "$theme_info"
        echo "$i) $theme_name - $theme_desc"
        ((i++))
    done
    
    local choice
    read -p "Выберите тему (1-${#themes[@]}, по умолчанию 1): " choice
    
    # По умолчанию robbyrussell
    local selected_theme="robbyrussell"
    
    # Проверка выбора
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#themes[@]}" ]; then
        IFS=':' read -r selected_theme _ <<< "${themes[$((choice-1))]}"
    fi
    
    echo "$selected_theme"
}

# Функция для установки темы Powerlevel10k
install_powerlevel10k() {
    print_status "Установка темы Powerlevel10k..."
    
    if [ "$INTERACTIVE" = true ]; then
        local choice
        read -p "Установить тему Powerlevel10k? [yes/no]: " choice
        case "$choice" in
            [Yy]|[Yy][Ee][Ss]|[Dd][Aa]|да|Да|ДА)
                # Продолжаем установку
                ;;
            *)
                print_debug "Установка Powerlevel10k пропущена"
                return
                ;;
        esac
    fi
    
    git clone -q --depth=1 https://github.com/romkatv/powerlevel10k.git $HOME/.powerlevel10k &>/dev/null
    check_success "Powerlevel10k установлен" "Ошибка установки Powerlevel10k"
    
    # Предлагаем установить шрифты Nerd Fonts
    if [ "$INTERACTIVE" = true ]; then
        install_nerd_fonts
    fi
}

# Функция для установки выбранной темы
install_zsh_theme() {
    print_header "Установка темы Zsh"
    
    local theme_name="robbyrussell"
    
    if [ "$INTERACTIVE" = true ]; then
        theme_name=$(select_theme)
    fi
    
    print_status "Выбрана тема: $theme_name"
    
    # Если выбрана Powerlevel10k, устанавливаем её
    if [ "$theme_name" = "powerlevel10k/powerlevel10k" ]; then
        if [ ! -d "$HOME/.powerlevel10k" ]; then
            install_powerlevel10k
        else
            print_success "Powerlevel10k уже установлен"
        fi
    fi
    
    # Сохраняем выбранную тему для использования в конфигурации
    SELECTED_THEME="$theme_name"
    
    print_success "Тема $theme_name выбрана успешно"
}

# Функция для установки дополнительных инструментов разработки
install_dev_tools() {
    print_header "Установка инструментов для разработки"
    
    local tools_to_install=()  # Массив для хранения выбранных инструментов
    
    # Группы инструментов с описаниями
    local tool_groups=(
        "Базовые инструменты:Основные утилиты для работы в командной строке:curl,wget,git,htop,ncdu"
        "Работа с текстом:Утилиты для поиска и обработки текста:fzf,ripgrep,bat,fd-find,jq"
        "Разработка кода:Инструменты для разработки программ:ctags,clang,cmake,ninja-build,make"
        "Сетевые утилиты:Инструменты для работы с сетью:nmap,netcat,iperf3,net-tools,curl"
        "Системные утилиты:Утилиты для мониторинга и управления системой:htop,neofetch,lsof,strace,dstat"
        "Базы данных:Клиенты для баз данных:sqlite3,postgresql-client,mysql-client,redis-tools"
    )
    
    echo -e "Доступные категории инструментов:"
    
    # Выводим группы инструментов
    local i=1
    for group in "${tool_groups[@]}"; do
        local group_name="${group%%:*}"
        local group_desc="${group#*:}"
        group_desc="${group_desc%%:*}"
        echo -e "$i) $group_name - $group_desc"
        ((i++))
    done
    
    echo -e "0) Завершить выбор"
    
    # Выбор групп инструментов
    local selected_groups=
    local choice
    while true; do
        read -p "Выберите категорию инструментов (1-${#tool_groups[@]}) или 0 для завершения: " choice
        
        if [[ "$choice" == "0" ]]; then
            break
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#tool_groups[@]}" ]; then
            local index=$((choice-1))
            local selected_group="${tool_groups[$index]}"
            local group_name="${selected_group%%:*}"
            local tools="${selected_group##*:}"
            
            if [[ "$selected_groups" != *"$group_name"* ]]; then
                tools_to_install+=(${tools//,/ })
                selected_groups="$selected_groups $group_name"
                print_status "Добавлена категория: $group_name"
            else
                print_warning "Категория $group_name уже выбрана"
            fi
        else
            print_warning "Неверный выбор. Повторите ввод."
        fi
    done
    
    # Удаляем дублирующиеся инструменты
    local unique_tools=()
    for tool in "${tools_to_install[@]}"; do
        if [[ ! " ${unique_tools[*]} " =~ " $tool " ]]; then
            unique_tools+=("$tool")
        fi
    done
    
    # Установка выбранных инструментов
    if [ ${#unique_tools[@]} -gt 0 ]; then
        print_status "Установка выбранных инструментов: ${unique_tools[*]}"
        
        local installed_count=0
        for tool in "${unique_tools[@]}"; do
            install_package "$tool" && ((installed_count++))
        done
        
        INSTALLED_TOOLS="${unique_tools[*]}"
        print_success "Успешно установлено инструментов: $installed_count из ${#unique_tools[@]}"
    else
        print_warning "Инструменты не выбраны, установка пропущена"
    fi
}

# Функция для настройки Git
configure_git() {
    print_header "Настройка Git"
    
    if ! command -v git &>/dev/null; then
        print_warning "Git не установлен. Пропуск настройки Git."
        return
    fi
    
    print_status "Настройка .gitconfig..."
    
    # Проверяем, есть ли настройки пользователя
    local git_name=$(git config --global user.name)
    local git_email=$(git config --global user.email)
    
    if [ "$INTERACTIVE" = true ]; then
        if [ -z "$git_name" ]; then
            read -p "Введите ваше имя для Git: " git_name
            if [ -n "$git_name" ]; then
                git config --global user.name "$git_name"
            fi
        else
            print_status "Git user.name уже настроен: $git_name"
        fi
        
        if [ -z "$git_email" ]; then
            read -p "Введите ваш email для Git: " git_email
            if [ -n "$git_email" ]; then
                git config --global user.email "$git_email"
            fi
        else
            print_status "Git user.email уже настроен: $git_email"
        fi
    fi
    
    # Настройка алиасов Git
    print_status "Настройка алиасов Git..."
    
    # Основные алиасы
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.ci commit
    git config --global alias.st status
    git config --global alias.unstage 'reset HEAD --'
    git config --global alias.last 'log -1 HEAD'
    git config --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
    
    # Настройка редактора
    if command -v vim &>/dev/null; then
        git config --global core.editor vim
    fi
    
    # Настройка цветного вывода
    git config --global color.ui auto
    
    print_success "Git настроен"
}

# Функция для настройки Zsh
configure_zsh() {
    print_header "Настройка конфигурации"
    print_status "Настройка .zshrc..."
    
    print_debug "Выбранная тема: $SELECTED_THEME"
    print_debug "Выбранные плагины: $SELECTED_PLUGINS"
    
    # Используем выбранную тему или по умолчанию
    local theme="$SELECTED_THEME"
    
    # Используем выбранные плагины или по умолчанию
    local plugins="$SELECTED_PLUGINS"

# Создаём базовый конфигурационный файл
cat > "$HOME/.zshrc" << EOL
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="$theme"

# Настройки истории
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_ALL_DUPS  # Игнорировать дубликаты в истории
setopt HIST_FIND_NO_DUPS     # Игнорировать дубликаты при поиске
setopt HIST_REDUCE_BLANKS    # Убирать лишние пробелы
setopt INC_APPEND_HISTORY    # Добавлять команды в историю сразу
setopt EXTENDED_HISTORY      # Добавлять временные метки
setopt HIST_EXPIRE_DUPS_FIRST # Удалять дубликаты первыми при переполнении истории
setopt SHARE_HISTORY         # Делиться историей между сессиями

# Plugins
plugins=($plugins)

# Source oh-my-zsh
source $ZSH/oh-my-zsh.sh

# User configuration
export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
export EDITOR='vim'

# Алиасы для работы с историей
alias h='history'
alias hg='history | grep'  # Поиск в истории
alias hs='history | grep -i'  # Поиск в истории без учета регистра
alias hf='history 1 | grep'  # Поиск по всей истории

# Привязка клавиш для поиска в истории
bindkey '^[[A' history-substring-search-up      # Стрелка вверх
bindkey '^[[B' history-substring-search-down    # Стрелка вниз
bindkey '^P' up-line-or-history                # Ctrl+P - предыдущая команда
bindkey '^N' down-line-or-history              # Ctrl+N - следующая команда

# Настройки для autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
EOL

    check_success "Конфигурационный файл создан" "Ошибка создания конфигурационного файла"
    
    # Если Powerlevel10k установлен, добавляем строку для загрузки его конфига
    if [ -d "$HOME/.powerlevel10k" ]; then
        print_status "Добавление настроек Powerlevel10k..."
        echo "# To customize prompt, run 'p10k configure' or edit ~/.p10k.zsh" >> "$HOME/.zshrc"
        echo "[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh" >> "$HOME/.zshrc"
    fi
}

# Функция для установки Zsh как оболочки по умолчанию
set_zsh_as_default_shell() {
    print_status "Установка Zsh как оболочки по умолчанию..."
    
    # Проверяем, является ли Zsh уже оболочкой по умолчанию
    local current_shell=$(getent passwd $USER | cut -d: -f7)
    if [[ "$current_shell" == "/bin/zsh" || "$current_shell" == "/usr/bin/zsh" ]]; then
        print_success "Zsh уже установлен как оболочка по умолчанию"
        return
    fi
    
    # Проверяем, добавлен ли Zsh в /etc/shells
    if ! grep -q "$(which zsh)" /etc/shells; then
        print_status "Добавление Zsh в /etc/shells..."
        echo "$(which zsh)" | sudo tee -a /etc/shells &>/dev/null
    fi
    
    # Изменяем оболочку по умолчанию
    if ! sudo chsh -s $(which zsh) $USER &>/dev/null; then
        print_warning "Не удалось изменить оболочку по умолчанию. Запустите команду вручную:"
        echo "chsh -s $(which zsh)"
    else
        print_success "Zsh установлен как оболочка по умолчанию"
    fi
}

# Функция для настройки Tmux
configure_tmux() {
    print_header "Настройка Tmux"
    
    # Проверка, установлен ли Tmux
    if ! command -v tmux &>/dev/null; then
        print_warning "Tmux не установлен. Устанавливаем..."
        install_package tmux
    else
        print_success "Tmux уже установлен"
    fi
    
    # Создаём резервную копию .tmux.conf если он существует
    if [ -f "$HOME/.tmux.conf" ] && [ "$MAKE_BACKUP" = true ]; then
        backup_file "$HOME/.tmux.conf"
    fi
    
    print_status "Создание конфигурации Tmux..."
    
    # Создаём конфигурацию Tmux
    cat > "$HOME/.tmux.conf" << 'EOL'
# Change the prefix key to C-a
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# Turn on mouse support
set -g mouse on

# Start window numbering at 1
set -g base-index 1

# Start pane numbering at 1
setw -g pane-base-index 1

# Reload config file with r
bind r source-file ~/.tmux.conf \; display-message "Config reloaded!"

# Split panes using | and -
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# Switch panes using Alt-arrow without prefix
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Shift arrow to switch windows
bind -n S-Left  previous-window
bind -n S-Right next-window

# Enable vi mode
set-window-option -g mode-keys vi

# Setup 'v' to begin selection as in Vim
bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi y send-keys -X copy-selection

# Improve colors and statusbar
set -g default-terminal "screen-256color"

# Set status bar
set -g status-bg black
set -g status-fg white
set -g status-left-length 30
set -g status-left '#[fg=green](#S) #(whoami) '
set -g status-right '#[fg=yellow]#(cut -d " " -f 1-3 /proc/loadavg)#[default] #[fg=white]%H:%M#[default]'

# Set window notifications
setw -g monitor-activity on
set -g visual-activity on

# Automatically set window title
setw -g automatic-rename on
set -g set-titles on

# No delay for escape key press
set -sg escape-time 0

# History settings
set -g history-limit 10000

# Aggressive window resizing
setw -g aggressive-resize on

# Easy movement between windows
bind C-p previous-window
bind C-n next-window

# Set easier window split keys
bind v split-window -h
bind h split-window -v

# Use Alt-Vim keys without prefix key to switch panes
bind -n M-h select-pane -L
bind -n M-j select-pane -D
bind -n M-k select-pane -U
bind -n M-l select-pane -R
EOL
    
    # Добавляем алиасы Tmux в .zshrc
    if [ -f "$HOME/.zshrc" ]; then
        print_status "Добавление алиасов Tmux в .zshrc"
        echo "" >> "$HOME/.zshrc"
        echo "# Tmux aliases" >> "$HOME/.zshrc"
        echo "alias t='tmux'" >> "$HOME/.zshrc"
        echo "alias ta='tmux attach -t'" >> "$HOME/.zshrc"
        echo "alias tls='tmux ls'" >> "$HOME/.zshrc"
        echo "alias tn='tmux new-session -s'" >> "$HOME/.zshrc"
    fi
    
    print_success "Tmux успешно настроен"
}

# Функция настройки Vim
configure_vim() {
    print_header "Настройка Vim"
    
    # Проверка, установлен ли Vim
    if ! command -v vim &>/dev/null; then
        print_warning "Vim не установлен. Устанавливаем..."
        install_package vim
    else
        print_success "Vim уже установлен"
    fi
    
    # Создаём резервную копию .vimrc если он существует
    if [ -f "$HOME/.vimrc" ] && [ "$MAKE_BACKUP" = true ]; then
        backup_file "$HOME/.vimrc"
    fi
    
    print_status "Создание конфигурации Vim..."
    
    # Создаём конфигурацию Vim
    cat > "$HOME/.vimrc" << 'EOL'
" Basic Vim configuration
syntax on                   " Enable syntax highlighting
set number                  " Show line numbers
set relativenumber          " Show relative line numbers
set autoindent              " Auto-indent new lines
set smartindent             " Enable smart-indent
set expandtab               " Use spaces instead of tabs
set smarttab                " Enable smart-tabs
set tabstop=4               " Number of spaces per Tab
set softtabstop=4           " Number of spaces per Tab in insert mode
set shiftwidth=4            " Number of spaces to use for autoindent
set showcmd                 " Show command in bottom bar
set cursorline              " Highlight current line
set wildmenu                " Visual autocomplete for command menu
set lazyredraw              " Redraw only when we need to
set showmatch               " Highlight matching [{()}]
set incsearch               " Search as characters are entered
set hlsearch                " Highlight matches
set foldenable              " Enable folding
set foldlevelstart=10       " Open most folds by default
set foldmethod=indent       " Fold based on indent level

filetype plugin indent on   " Load filetype-specific indent files

" Key mappings
let mapleader = ","         " Leader is comma

" turn off search highlight
nnoremap <leader><space> :nohlsearch<CR>

" space open/closes folds
nnoremap <space> za

" move vertically by visual line
nnoremap j gj
nnoremap k gk

" move to beginning/end of line
nnoremap B ^              
nnoremap E $

" $/^ doesn't do anything
nnoremap $ <nop>
nnoremap ^ <nop>

" highlight last inserted text
nnoremap gV `[v`]

" Toggle relative line numbers
nnoremap <leader>n :set relativenumber!<CR>

" Toggle paste mode
set pastetoggle=<F2>

" Save with leader w
nnoremap <leader>w :w<CR>

" Quit with leader q
nnoremap <leader>q :q<CR>

" Colors and themes
set background=dark        " Use dark background
set termguicolors          " Use GUI colors in terminal if available

" Backup and swap files
set backup                  " Turn on backups
set backupdir=~/.vim/backup/  " Backup directory
set directory=~/.vim/swap/    " Swap file directory

" Create directories if they don't exist
if !isdirectory(expand("~/.vim/backup"))
  silent !mkdir -p ~/.vim/backup
endif

if !isdirectory(expand("~/.vim/swap"))
  silent !mkdir -p ~/.vim/swap
endif

" Status line
set laststatus=2           " Always show status line
set statusline=%F%m%r%h%w\ [FORMAT=%{&ff}]\ [TYPE=%Y]\ [POS=%l,%v][%p%%]\ [BUFFER=%n]\ %{strftime('%c')}

" File type specific settings
autocmd FileType html setlocal shiftwidth=2 tabstop=2
autocmd FileType css setlocal shiftwidth=2 tabstop=2
autocmd FileType javascript setlocal shiftwidth=2 tabstop=2
catch
endtry
EOL
    
    print_success "Настройка Vim завершена"
}

# Функция для экспорта настроек
export_settings() {
    print_header "Экспорт настроек"
    
    local export_dir="$HOME/.zsh_settings"
    local export_file="$export_dir/settings_$(date +"%Y%m%d_%H%M%S").tar.gz"
    
    # Создаем директорию для экспорта
    mkdir -p "$export_dir"
    
    # Файлы для экспорта
    local files_to_export=(
        "$HOME/.zshrc"
        "$HOME/.oh-my-zsh"
        "$HOME/.p10k.zsh"
        "$HOME/.powerlevel10k"
        "$HOME/.vimrc"
        "$HOME/.tmux.conf"
    )
    
    # Создаем временную директорию
    local temp_dir=$(mktemp -d)
    
    # Создаем файл с информацией о системе
    print_status "Сохранение информации о системе..."
    {
        echo "# Информация о системе"
        echo "EXPORT_DATE=\"$(date)\""
        echo "DISTRO=\"$(get_distro)\""
        echo "SHELL=\"$SHELL\""
        echo "USER=\"$USER\""
        echo "HOSTNAME=\"$(hostname)\""
        echo "ZSH_VERSION=\"$(zsh --version 2>/dev/null || echo 'Not installed')\""
        echo "VIM_VERSION=\"$(vim --version 2>/dev/null | head -n 1 || echo 'Not installed')\""
        echo "TMUX_VERSION=\"$(tmux -V 2>/dev/null || echo 'Not installed')\""
        echo "SELECTED_THEME=\"$SELECTED_THEME\""
        echo "SELECTED_PLUGINS=\"$SELECTED_PLUGINS\""
        echo "INSTALLED_FONT=\"$INSTALLED_FONT\""
        echo "INSTALLED_TOOLS=\"$INSTALLED_TOOLS\""
    } > "$temp_dir/system_info.txt"
    
    # Копируем файлы во временную директорию
    print_status "Копирование файлов конфигурации..."
    for file in "${files_to_export[@]}"; do
        if [ -e "$file" ]; then
            # Создаем структуру директорий во временной папке
            mkdir -p "$temp_dir$(dirname $file)"
            cp -r "$file" "$temp_dir$file"
        fi
    done
    
    # Создаем архив
    print_status "Создание архива..."
    if ! tar -czf "$export_file" -C "$temp_dir" .; then
        print_error "Ошибка при создании архива"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Очистка
    rm -rf "$temp_dir"
    
    print_success "Настройки экспортированы в $export_file"
}

# Функция для импорта настроек
import_settings() {
    print_header "Импорт настроек"
    
    # Запрос пути к файлу настроек
    local import_file=""
    
    if [ "$1" ] && [ -f "$1" ]; then
        import_file="$1"
    else
        local export_dir="$HOME/.zsh_settings"
        if [ ! -d "$export_dir" ]; then
            print_error "Директория $export_dir не существует"
            return 1
        fi
        
        # Получаем список файлов настроек
        local settings_files=("$export_dir"/*.tar.gz)
        
        if [ ${#settings_files[@]} -eq 0 ]; then
            print_error "Файлы настроек не найдены в $export_dir"
            return 1
        fi
        
        # Показываем список файлов
        echo "Доступные файлы настроек:"
        local i=1
        for file in "${settings_files[@]}"; do
            echo "$i) $(basename $file)"
            ((i++))
        done
        
        local choice
        read -p "Выберите файл (1-${#settings_files[@]}): " choice
        
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#settings_files[@]}" ]; then
            print_error "Неверный выбор"
            return 1
        fi
        
        import_file="${settings_files[$((choice-1))]}"
    fi
    
    print_status "Импорт настроек из $import_file..."
    
    # Создаем резервные копии существующих файлов
    check_and_remove_existing
    
    # Распаковываем архив во временную директорию
    local temp_dir=$(mktemp -d)
    if ! tar -xzf "$import_file" -C "$temp_dir"; then
        print_error "Ошибка при распаковке архива"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Чтение информации о системе
    if [ -f "$temp_dir/system_info.txt" ]; then
        print_status "Информация о системе из архива:"
        cat "$temp_dir/system_info.txt"
        
        # Загружаем переменные
        source "$temp_dir/system_info.txt"
    fi
    
    # Копируем файлы в домашнюю директорию
    print_status "Восстановление файлов конфигурации..."
    if [ -d "$temp_dir$HOME" ]; then
        cp -r "$temp_dir$HOME/." "$HOME/"
    fi
    
    # Очистка
    rm -rf "$temp_dir"
    
    print_success "Настройки успешно импортированы из $import_file"
}

# Функция для вывода завершающего сообщения
print_installation_complete() {
    print_header "Установка завершена"
    
    echo -e "${GREEN}Zsh и Oh My Zsh успешно установлены!${NC}"
    echo -e ""
    echo -e "${BLUE}Для начала работы:${NC}"
    echo -e "1. Перезапустите терминал"
    echo -e "2. Или выполните команду: ${BOLD}zsh${NC}"
    
    if [ -d "$HOME/.powerlevel10k" ]; then
        echo -e ""
        echo -e "${YELLOW}Для настройки темы Powerlevel10k выполните:${NC}"
        echo -e "p10k configure"
    fi
    
    # Добавляем информацию о дополнительных компонентах
    local extras=""
    [ -n "$INSTALLED_FONT" ] && extras="${extras}${extras:+, }шрифт $INSTALLED_FONT"
    [ -f "$HOME/.vimrc" ] && extras="${extras}${extras:+, }Vim"
    [ -f "$HOME/.tmux.conf" ] && extras="${extras}${extras:+, }Tmux"
    [ -n "$INSTALLED_TOOLS" ] && extras="${extras}${extras:+, }$INSTALLED_TOOLS"
    
    if [ -n "$extras" ]; then
        echo -e ""
        echo -e "${BLUE}Установленные дополнительные компоненты:${NC}"
        echo -e "$extras"
    fi
    
    echo -e ""
    echo -e "${BLUE}Дополнительные возможности:${NC}"
    echo -e "- Экспорт настроек: ${BOLD}$0 --export${NC}"
    echo -e "- Импорт настроек: ${BOLD}$0 --import${NC}"
    
    if [ "$DEBUG" = true ]; then
        echo -e ""
        echo -e "${BLUE}Журнал установки сохранен в файле:${NC} $HOME/.zsh_install.log"
    fi
}

# Подготовка к выполнению основной функции
if [ "$DEBUG" = true ]; then
    print_debug "Запуск скрипта с параметрами:"
    print_debug "INTERACTIVE: $INTERACTIVE"
    print_debug "MAKE_BACKUP: $MAKE_BACKUP"
    print_debug "DEBUG: $DEBUG"
    print_debug "QUIET: $QUIET"
    print_debug "EXPORT_SETTINGS: $EXPORT_SETTINGS"
    print_debug "IMPORT_SETTINGS: $IMPORT_SETTINGS"
    print_debug "IMPORT_FILE: $IMPORT_FILE"
    print_debug "CONFIGURE_VIM: $CONFIGURE_VIM"
    print_debug "CONFIGURE_TMUX: $CONFIGURE_TMUX"
fi

# Функция для создания шпаргалки Zsh
create_cheatsheet() {
    print_header "Создание шпаргалки Zsh"
    
    local cheatsheet_file="$HOME/.zsh_cheatsheet.md"
    
    # Создаем шпаргалку в формате Markdown
    cat > "$cheatsheet_file" << 'EOL'
# Шпаргалка Zsh

## Основные сочетания клавиш

### Навигация по командной строке
- `Ctrl+A` - переход в начало строки
- `Ctrl+E` - переход в конец строки
- `Alt+F` / `Esc+F` - вперед на одно слово
- `Alt+B` / `Esc+B` - назад на одно слово
- `Ctrl+U` - удалить от курсора до начала строки
- `Ctrl+K` - удалить от курсора до конца строки
- `Alt+D` / `Esc+D` - удалить слово после курсора
- `Ctrl+W` - удалить слово перед курсором
- `Ctrl+R` - поиск в истории (incremental search)
- `Ctrl+G` - отмена поиска в истории
- `Ctrl+L` - очистить экран

### История команд
- `↑` / `↓` - предыдущая/следующая команда в истории
- `!!` - повторить последнюю команду
- `!$` - последний аргумент предыдущей команды
- `!n` - команда номер n из истории
- `!string` - последняя команда, начинающаяся с string
- `!?string` - последняя команда, содержащая string

## Алиасы и функции из Oh My Zsh

### Git
- `ga` - git add
- `gc` - git commit
- `gp` - git push
- `gl` - git pull
- `gst` - git status
- `gd` - git diff
- `gco` - git checkout
- `gb` - git branch
- `gcb` - git checkout -b
- `gm` - git merge

### Навигация по директориям
- `..` - cd ..
- `...` - cd ../..
- `....` - cd ../../..
- `~` - cd ~
- `-` - cd -

### Часто используемые алиасы
- `l` - ls -lah
- `la` - ls -lAh
- `ll` - ls -lh
- `md` - mkdir -p
- `rd` - rmdir

## Полезные трюки

### Замена в предыдущей команде
- `^foo^bar` - заменить первое вхождение foo на bar в предыдущей команде и выполнить её

### Перенаправление вывода
- `cmd > file` - перенаправить stdout в file
- `cmd >> file` - добавить stdout в file
- `cmd 2> file` - перенаправить stderr в file
- `cmd &> file` - перенаправить stdout и stderr в file

### Управление заданиями
- `Ctrl+Z` - приостановить выполнение программы
- `fg` - продолжить выполнение программы на переднем плане
- `bg` - продолжить выполнение программы в фоне
- `jobs` - показать список приостановленных заданий

### Подстановки
- `!!` - последняя команда
- `!$` - последний аргумент предыдущей команды
- `!*` - все аргументы предыдущей команды
- `!-2` - предпоследняя команда
- `{}` - генерация списков (echo file{1,2,3} → file1 file2 file3)

## Tmux (если установлен)

### Основные команды
- `tmux` - запустить новую сессию
- `tmux ls` - список сессий
- `tmux attach -t [имя]` - подключиться к существующей сессии

### Сочетания клавиш (после Ctrl+a или Ctrl+b)
- `c` - создать новое окно
- `n` - перейти к следующему окну
- `p` - перейти к предыдущему окну
- `"` - разделить окно горизонтально
- `%` - разделить окно вертикально
- `стрелки` - перемещение между панелями
- `d` - отключиться от сессии

## Исправление ошибок

### Исправление опечаток
Когда вы делаете опечатку, Zsh может предложить исправление. Нажмите `y`, чтобы принять исправление.

### Глобальные подстановки
- `!!:gs/foo/bar` - заменить все вхождения foo на bar в предыдущей команде и выполнить её

## Избранные плагины Oh My Zsh

### zsh-syntax-highlighting
Подсветка синтаксиса команд в реальном времени. Некорректные команды будут выделены красным.

### zsh-autosuggestions
Автоматические предложения на основе истории команд. Используйте стрелку вправо для принятия предложения.

### history-substring-search
Позволяет искать в истории, используя начало строки. Начните вводить и нажмите стрелку вверх.

### autojump
Быстрая навигация по часто используемым директориям. Используйте `j директория` вместо `cd`.
EOL

    # Делаем шпаргалку доступной для чтения
    chmod 644 "$cheatsheet_file"
    
    print_success "Шпаргалка Zsh создана в $cheatsheet_file"
    print_status "Чтобы просмотреть шпаргалку, выполните: less $cheatsheet_file"
    
    # Добавляем алиас в .zshrc, если он существует
    if [ -f "$HOME/.zshrc" ]; then
        if ! grep -q "alias zhelp=" "$HOME/.zshrc"; then
            echo "" >> "$HOME/.zshrc"
            echo "# Быстрый доступ к шпаргалке Zsh" >> "$HOME/.zshrc"
            echo "alias zhelp='less ~/.zsh_cheatsheet.md'" >> "$HOME/.zshrc"
            print_status "Добавлен алиас 'zhelp' для быстрого доступа к шпаргалке"
        fi
    fi
}

# Функция для проверки конфигурации
check_configuration() {
    print_header "Проверка конфигурации"
    
    local issues_found=0
    local warnings=0
    
    # Проверка Zsh
    if ! command -v zsh &>/dev/null; then
        print_error "Zsh не установлен"
        ((issues_found++))
    else
        print_success "Zsh установлен: $(zsh --version)"
    fi
    
    # Проверка Oh My Zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        print_warning "Oh My Zsh не установлен"
        ((warnings++))
    else
        print_success "Oh My Zsh установлен"
    fi
    
    # Проверка .zshrc
    if [ ! -f "$HOME/.zshrc" ]; then
        print_warning "Файл .zshrc не найден"
        ((warnings++))
    else
        print_success "Файл .zshrc найден"
        
        # Проверка темы
        if ! grep -q "ZSH_THEME=" "$HOME/.zshrc"; then
            print_warning "Тема ZSH не настроена в .zshrc"
            ((warnings++))
        else
            local current_theme=$(grep -o 'ZSH_THEME="[^"]*"' "$HOME/.zshrc" | cut -d'"' -f2)
            print_success "Текущая тема: $current_theme"
        fi
        
        # Проверка плагинов
        if ! grep -q "plugins=(" "$HOME/.zshrc"; then
            print_warning "Плагины ZSH не настроены в .zshrc"
            ((warnings++))
        else
            local current_plugins=$(grep -o 'plugins=([^)]*)' "$HOME/.zshrc" | sed 's/plugins=(//;s/)//;s/"//g')
            print_success "Текущие плагины: $current_plugins"
        fi
    fi
    
    # Проверка стандартной оболочки
    if [ "$SHELL" != "$(which zsh)" ]; then
        print_warning "Zsh не установлен как стандартная оболочка (сейчас: $SHELL)"
        ((warnings++))
    else
        print_success "Zsh установлен как стандартная оболочка"
    fi
    
    # Проверка Vim
    if command -v vim &>/dev/null; then
        print_success "Vim установлен: $(vim --version | head -n 1)"
        
        if [ -f "$HOME/.vimrc" ]; then
            print_success "Файл .vimrc найден"
        else
            print_warning "Файл .vimrc не найден"
            ((warnings++))
        fi
    fi
    
    # Проверка Tmux
    if command -v tmux &>/dev/null; then
        print_success "Tmux установлен: $(tmux -V)"
        
        if [ -f "$HOME/.tmux.conf" ]; then
            print_success "Файл .tmux.conf найден"
        else
            print_warning "Файл .tmux.conf не найден"
            ((warnings++))
        fi
    fi
    
    # Итоги проверки
    print_header "Результаты проверки"
    if [ $issues_found -eq 0 ] && [ $warnings -eq 0 ]; then
        print_success "Конфигурация в отличном состоянии!"
    elif [ $issues_found -eq 0 ]; then
        print_warning "Конфигурация имеет $warnings предупреждений, но критических проблем не обнаружено"
    else
        print_error "Обнаружено $issues_found проблем и $warnings предупреждений"
    fi
    
    return $issues_found
}

# Запуск основной функции
main
