#!/bin/bash

# Убедитесь, что все необходимые параметры переданы в скрипт
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <registration-token>"
    exit 1
fi

# Параметры для регистрации GitLab Runner
GITLAB_URL="https://gitlab.com/"
REGISTRATION_TOKEN="$1"
EXECUTOR="docker"
DESCRIPTION="Docker runner socket"
DOCKER_IMAGE="docker:latest"
DOCKER_VOLUMES="/var/run/docker.sock:/var/run/docker.sock"
TAG_LIST="lf-runner1"

# Выполнение команды регистрации
gitlab-runner register -n \
    --url "$GITLAB_URL" \
    --registration-token "$REGISTRATION_TOKEN" \
    --executor "$EXECUTOR" \
    --description "$DESCRIPTION" \
    --docker-image "$DOCKER_IMAGE" \
    --docker-volumes "$DOCKER_VOLUMES" \
    --tag-list "$TAG_LIST"

# Проверка успешности выполнения команды
if [ $? -eq 0 ]; then
    echo "GitLab Runner successfully registered."
else
    echo "Failed to register GitLab Runner."
    exit 1
fi
