#!/bin/bash
set -e

USER="tim" 
IP="192.168.55.1"
DIR="~/dissertation"

# Sync the current directory to the Jetson
rsync -avz --delete \
    --exclude 'target' \
    --exclude '__pycache__' \
    --exclude '.git' \
    --exclude '_deps' \
    --exclude 'CMakeCache.txt' \
    --exclude 'deploy.sh' \
    --exclude 'pull_results.sh' \
    ./ ${USER}@${IP}:${DIR}

# Build the Docker image on the Jetson
ssh ${USER}@${IP} << EOF
    cd ${DIR}
    docker build -t dissertation:latest .
EOF
