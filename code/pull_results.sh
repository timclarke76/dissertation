#!/bin/bash
set -e

USER="tim" 
IP="192.168.55.1"
DIR="~/dissertation"

TARGET="./results/$(date +'%Y-%m-%d_%H-%M-%S')"
mkdir -p ${TARGET}

rsync -avz --progress \
    --exclude 'settings.toml' \
    ${USER}@${IP}:${DIR}/results/ \
    ${TARGET}/
