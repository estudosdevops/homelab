#!/bin/bash

# Script de backup para configurações importantes
# Uso: ./backup.sh [destino]

BACKUP_DIR="${1:-/backup}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="homelab_backup_$DATE.tar.gz"

# Verifica se o diretório de backup existe
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Criando diretório de backup: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
fi

# Lista de diretórios para backup
DIRS_TO_BACKUP=(
    "/etc/ansible"
    "/home/user/docker-compose"
    # Adicione mais diretórios conforme necessário
)

# Criando backup
echo "Iniciando backup..."
tar -czf "$BACKUP_DIR/$BACKUP_FILE" "${DIRS_TO_BACKUP[@]}" 2>/dev/null

# Verifica se o backup foi bem sucedido
if [ $? -eq 0 ]; then
    echo "Backup concluído com sucesso: $BACKUP_DIR/$BACKUP_FILE"
else
    echo "Erro ao criar backup!"
    exit 1
fi

# Mantém apenas os últimos 7 backups
find "$BACKUP_DIR" -name "homelab_backup_*.tar.gz" -mtime +7 -delete

exit 0
