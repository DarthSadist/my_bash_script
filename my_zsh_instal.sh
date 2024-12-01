#!/bin/bash

# Определение цветов для вывода
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Функция для красивого вывода
print_status() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✔]${NC} $1"
}

print_error() {
    echo -e "${RED}[✘]${NC} $1"
}

print_header() {
    echo -e "\n${BOLD}$1${NC}"
    echo -e "${BOLD}$(printf '%.0s-' {1..50})${NC}\n"
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
    
    # Проверка и удаление Oh My Zsh
    if [ -d "$HOME/.oh-my-zsh" ]; then
        print_status "Удаление Oh My Zsh..."
        rm -rf "$HOME/.oh-my-zsh" &>/dev/null
    fi

    # Проверка и удаление Powerlevel10k
    if [ -d "$HOME/.powerlevel10k" ]; then
        print_status "Удаление Powerlevel10k..."
        rm -rf "$HOME/.powerlevel10k" &>/dev/null
    fi

    # Проверка и удаление конфигурационных файлов
    if [ -f "$HOME/.zshrc" ]; then
        print_status "Удаление конфигурационных файлов..."
        rm -f "$HOME/.zshrc" &>/dev/null
    fi

    # Удаление папки my_zsh если она существует
    if [ -d "$HOME/my_zsh" ]; then
        rm -rf "$HOME/my_zsh" &>/dev/null
    fi

    print_success "Очистка завершена"
}

# Функция для проверки и установки пакетов
install_package() {
    PACKAGE_NAME=$1
    if ! command -v $PACKAGE_NAME &> /dev/null; then
        print_status "Установка $PACKAGE_NAME..."
        sudo apt install -y $PACKAGE_NAME &>/dev/null
        check_success "$PACKAGE_NAME установлен" "Ошибка установки $PACKAGE_NAME"
    fi
}

# Функция для проверки успешности выполнения команды
check_success() {
    if [ $? -eq 0 ]; then
        print_success "$1"
    else
        print_error "$2"
        exit 1
    fi
}

# Запускаем проверку и удаление перед установкой
check_and_remove_existing

# Обновление списков пакетов
print_header "Установка необходимых компонентов"
print_status "Обновление списков пакетов..."
sudo apt update &>/dev/null
check_success "Списки пакетов обновлены" "Ошибка обновления списков пакетов"

# Установка Git
install_package git

# Установка Oh My Zsh
print_header "Установка Oh My Zsh"
print_status "Установка Oh My Zsh..."

# Проверяем наличие wget и fzf
if ! command -v wget &>/dev/null; then
    print_status "Установка wget..."
    sudo apt install -y wget &>/dev/null
    check_success "wget установлен" "Ошибка установки wget"
fi

# Установка fzf
print_status "Установка fzf..."
if ! command -v fzf &>/dev/null; then
    sudo apt install -y fzf &>/dev/null
    check_success "fzf установлен" "Ошибка установки fzf"
fi

# Загрузка и установка Oh My Zsh
if [ -d "$HOME/.oh-my-zsh" ]; then
    print_status "Удаление старой версии Oh My Zsh..."
    rm -rf "$HOME/.oh-my-zsh"
fi

if [ -f "$HOME/.zshrc" ]; then
    print_status "Удаление старого конфигурационного файла..."
    rm -f "$HOME/.zshrc"
fi

print_status "Загрузка установщика Oh My Zsh..."
wget -O install.sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh 2>/dev/null || {
    print_error "Ошибка загрузки установщика Oh My Zsh"
    exit 1
}

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

# Установка плагинов
print_header "Установка плагинов и темы"
print_status "Установка плагина zsh-syntax-highlighting..."
git clone -q https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting &>/dev/null
check_success "zsh-syntax-highlighting установлен" "Ошибка установки zsh-syntax-highlighting"

print_status "Установка плагина zsh-autosuggestions..."
git clone -q https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions &>/dev/null
check_success "zsh-autosuggestions установлен" "Ошибка установки zsh-autosuggestions"

# Установка темы Powerlevel10k
print_status "Установка темы Powerlevel10k..."
git clone -q --depth=1 https://github.com/romkatv/powerlevel10k.git $HOME/.powerlevel10k &>/dev/null
check_success "Powerlevel10k установлен" "Ошибка установки Powerlevel10k"

# Создание базового конфигурационного файла, если не удалось скачать
print_header "Настройка конфигурации"
print_status "Настройка .zshrc..."

# Создаём базовый конфигурационный файл
cat > "$HOME/.zshrc" << 'EOL'
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="robbyrussell"

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
plugins=(
    git
    zsh-syntax-highlighting
    zsh-autosuggestions
    history-substring-search  # Поиск по истории с подсветкой
)

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

# Установка Zsh как оболочки по умолчанию
print_status "Установка Zsh как оболочки по умолчанию..."
sudo chsh -s $(which zsh) $USER &>/dev/null
check_success "Zsh установлен как оболочка по умолчанию" "Ошибка установки Zsh как оболочки по умолчанию"

print_header "Установка завершена"
echo -e "${GREEN}Zsh и Oh My Zsh успешно установлены!${NC}"
echo -e "${BLUE}Для начала работы:${NC}"
echo -e "1. Перезапустите терминал"
echo -e "2. Или выполните команду: ${BOLD}zsh${NC}"
