#!/bin/bash

# Проверка, запущен ли скрипт с правами суперпользователя
if [ "$EUID" -ne 0 ]; then
    echo "Пожалуйста, запустите этот скрипт с правами суперпользователя (например, с помощью sudo)."
    exit 1
fi

# Функция для проверки и установки пакетов
install_package() {
    PACKAGE_NAME=$1
    if ! command -v $PACKAGE_NAME &> /dev/null; then
        echo "Установка $PACKAGE_NAME..."
        apt install -y $PACKAGE_NAME
    else
        echo "$PACKAGE_NAME уже установлен."
    fi
}

# Обновление списков пакетов
echo "Обновление списков пакетов..."
sudo apt update

# Установка Zsh и Git
echo "Проверка наличия Zsh и Git..."
install_package git

# Установка Zsh
if ! command -v zsh &> /dev/null; then
    echo "Установка Zsh..."
    sudo apt install -y zsh || { echo "Не удалось установить Zsh. Проверьте репозитории."; exit 1; }
else
    echo "Zsh уже установлен."
fi

# Установка Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Установка Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "Oh My Zsh уже установлен."
fi

# Установка плагинов
echo "Установка плагинов zsh-syntax-highlighting и zsh-autosuggestions..."
if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
else
    echo "zsh-syntax-highlighting уже установлен."
fi

if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
else
    echo "zsh-autosuggestions уже установлен."
fi

# Установка темы Powerlevel10k
if [ ! -d "$HOME/.powerlevel10k" ]; then
    echo "Установка темы Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $HOME/.powerlevel10k
else
    echo "Powerlevel10k уже установлен."
fi

# Клонирование конфигурационного файла .zshrc
echo "Клонирование конфигурационного файла .zshrc..."
if [ -d "$HOME/my_zsh" ]; then
    echo "Репозиторий my_zsh уже клонирован."
else
    git clone https://github.com/DarthSadist/my_zsh.git $HOME/my_zsh
fi

# Проверка наличия .zshrc в репозитории
if [ -f "$HOME/my_zsh/.zshrc" ]; then
    echo "Копируем .zshrc в домашнюю директорию..."
    if [ -f "$HOME/.zshrc" ]; then
        mv "$HOME/.zshrc" "$HOME/.zshrc.bak"  # Резервное копирование существующего .zshrc
    fi
    mv "$HOME/my_zsh/.zshrc" "$HOME/.zshrc"
else
    echo "Ошибка: Файл .zshrc не найден в репозитории my_zsh."
    exit 1
fi

# Установка Zsh как оболочки по умолчанию
chsh -s $(which zsh)

echo -e "\nУстановка завершена. Пожалуйста, перезапустите терминал или выполните команду 'zsh' для начала работы с Zsh."
