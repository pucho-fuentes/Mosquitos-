#!/bin/bash
# Deployment script for mosquito monitor on Hostinger VPS
# Run this on the VPS as root: bash deploy.sh

set -e

echo "=== Desplegando monitor de mosquitos en VPS ==="

# Update system
apt-get update && apt-get upgrade -y

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Instalando Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo "Instalando Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Create project directory
mkdir -p /opt/mosquito-monitor
cd /opt/mosquito-monitor

# Create certbot directories
mkdir -p certbot/conf certbot/www

echo "=== Configuración completada ==="
echo "Ahora copia los archivos del proyecto a /opt/mosquito-monitor/"
echo "Luego ejecuta: docker-compose up -d"
echo "Y obtén el certificado SSL con:"
echo "  docker-compose run --rm certbot certonly --webroot -w /var/www/certbot -d mosquitos.keplering.tech --email tu@email.com --agree-tos --no-eff-email"
echo "Finalmente: docker-compose restart nginx"