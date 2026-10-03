#!/bin/bash
# Complete automated deployment for Hostinger VPS
# Run on VPS: curl -sSL https://raw.githubusercontent.com/.../deploy-full.sh | bash
# Or copy this file to VPS and run: bash deploy-full.sh

set -e

DOMAIN="mosquitos.keplering.tech"
EMAIL="admin@keplering.tech"  # Cambia esto por tu email real
PROJECT_DIR="/opt/mosquito-monitor"

echo "=== Despliegue completo automático ==="
echo "Dominio: $DOMAIN"
echo "Directorio: $PROJECT_DIR"

# 1. Update system
echo "[1/8] Actualizando sistema..."
apt-get update && apt-get upgrade -y

# 2. Install Docker
echo "[2/8] Instalando Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

# 3. Install Docker Compose
echo "[3/8] Instalando Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# 4. Create project directory
echo "[4/8] Creando directorio del proyecto..."
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# 5. Create certbot directories
mkdir -p certbot/conf certbot/www

# 6. Create all necessary files
echo "[5/8] Creando archivos de configuración..."

cat > Dockerfile << 'EOF'
FROM node:20-alpine
WORKDIR /app
COPY server.js .
COPY graficas.html .
COPY datos.json* ./
EXPOSE 3000
CMD ["node", "server.js"]
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  app:
    build: .
    container_name: mosquito-monitor
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - ./datos.json:/app/datos.json
    environment:
      - NODE_ENV=production

  nginx:
    image: nginx:alpine
    container_name: mosquito-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certbot/conf:/etc/letsencrypt:ro
      - ./certbot/www:/var/www/certbot:ro
    depends_on:
      - app

  certbot:
    image: certbot/certbot
    container_name: mosquito-certbot
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done'"

volumes:
  certbot-conf:
  certbot-www:
EOF

cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

    upstream app {
        server app:3000;
    }

    server {
        listen 80;
        server_name DOMAIN_PLACEHOLDER;

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location / {
            return 301 https://$server_name$request_uri;
        }
    }

    server {
        listen 443 ssl http2;
        server_name DOMAIN_PLACEHOLDER;

        ssl_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;

        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-Content-Type-Options "nosniff";
        add_header X-XSS-Protection "1; mode=block";

        gzip on;
        gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

        location / {
            proxy_pass http://app;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
            proxy_read_timeout 86400;
        }

        location /corriente {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://app;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF

# Replace domain placeholder
sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" nginx.conf

# Create empty datos.json
echo "[]" > datos.json

echo "[6/8] Archivos creados. Ahora necesitas copiar server.js y graficas.html a $PROJECT_DIR"
echo ""
echo "Ejecuta estos comandos en tu máquina local para copiar los archivos:"
echo "  scp server.js graficas.html root@62.72.35.43:$PROJECT_DIR/"
echo ""
echo "O si estás en el VPS y tienes los archivos en otro lugar:"
echo "  cp /ruta/a/server.js /ruta/a/graficas.html $PROJECT_DIR/"
echo ""
read -p "Presiona Enter cuando hayas copiado los archivos..."

# 7. Build and start containers
echo "[7/8] Construyendo y iniciando contenedores..."
docker-compose build
docker-compose up -d

# 8. Get SSL certificate
echo "[8/8] Obteniendo certificado SSL..."
docker-compose run --rm certbot certonly --webroot -w /var/www/certbot -d $DOMAIN --email $EMAIL --agree-tos --no-eff-email --non-interactive

# Restart nginx to use the new certificate
docker-compose restart nginx

echo ""
echo "=== ¡DESPLIEGUE COMPLETADO! ==="
echo "Tu dashboard está disponible en: https://$DOMAIN"
echo "La API está en: https://$DOMAIN/corriente"
echo ""
echo "Comandos útiles:"
echo "  Ver logs: docker-compose logs -f"
echo "  Reiniciar: docker-compose restart"
echo "  Actualizar: docker-compose pull && docker-compose up -d --build"
echo "  Ver estado: docker-compose ps"