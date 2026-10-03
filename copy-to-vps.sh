#!/bin/bash
# Script para copiar archivos al VPS desde Windows (Git Bash / WSL)
# Uso: bash copy-to-vps.sh

VPS_IP="62.72.35.43"
VPS_USER="root"
VPS_PATH="/opt/mosquito-monitor"
LOCAL_DIR="$(dirname "$0")"

echo "Copiando archivos al VPS $VPS_IP..."

# Copy project files
scp "$LOCAL_DIR/server.js" "$LOCAL_DIR/graficas.html" "$LOCAL_DIR/datos.json" "$LOCAL_DIR/Dockerfile" "$LOCAL_DIR/docker-compose.yml" "$LOCAL_DIR/nginx.conf" "$VPS_USER@$VPS_IP:$VPS_PATH/"

echo "¡Archivos copiados!"
echo "Ahora en el VPS ejecuta:"
echo "  cd $VPS_PATH && docker-compose up -d --build"
echo "  docker-compose run --rm certbot certonly --webroot -w /var/www/certbot -d mosquitos.keplering.tech --email TU_EMAIL --agree-tos --no-eff-email"
echo "  docker-compose restart nginx"