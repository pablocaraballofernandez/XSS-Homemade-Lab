#!/bin/bash
# ══════════════════════════════════════════════════════════════
# ZumoFresco — Script de instalación para Debian
# Ejecutar como root o con sudo
# ══════════════════════════════════════════════════════════════

set -e

echo "🍊 ══════════════════════════════════════════════════"
echo "   ZumoFresco — Instalación en Debian"
echo "   ══════════════════════════════════════════════════"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Actualizar sistema e instalar dependencias
echo -e "${YELLOW}[1/5] Actualizando sistema e instalando Python...${NC}"
apt update && apt upgrade -y
apt install -y python3 python3-pip python3-venv curl git

# 2. Crear usuario para la app (si no existe)
echo -e "${YELLOW}[2/5] Configurando usuario y directorio...${NC}"
if ! id "zumofresco" &>/dev/null; then
    useradd -m -s /bin/bash zumofresco
fi

APP_DIR="/opt/zumofresco"
mkdir -p "$APP_DIR"

# 3. Copiar archivos de la aplicación
echo -e "${YELLOW}[3/5] Instalando aplicación...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -r "$SCRIPT_DIR"/* "$APP_DIR/"
chown -R zumofresco:zumofresco "$APP_DIR"

# 4. Crear entorno virtual e instalar dependencias
echo -e "${YELLOW}[4/5] Configurando entorno Python...${NC}"
cd "$APP_DIR"
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Inicializar la base de datos
python3 -c "
import sys
sys.path.insert(0, '$APP_DIR')
from app import init_db
init_db()
print('Base de datos inicializada')
"

# 5. Crear servicio systemd
echo -e "${YELLOW}[5/5] Creando servicio systemd...${NC}"
cat > /etc/systemd/system/zumofresco.service << 'EOF'
[Unit]
Description=ZumoFresco Juice Shop
After=network.target

[Service]
User=zumofresco
Group=zumofresco
WorkingDirectory=/opt/zumofresco
Environment="PATH=/opt/zumofresco/venv/bin"
ExecStart=/opt/zumofresco/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 --access-logfile /opt/zumofresco/logs/gunicorn-access.log app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zumofresco
systemctl start zumofresco

# Mostrar IP
IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ ZumoFresco instalado correctamente!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  🌐 Web:        http://${IP}:5000"
echo -e "  📁 App:        /opt/zumofresco"
echo -e "  📄 Logs:       /opt/zumofresco/logs/"
echo -e "  🔧 Servicio:   systemctl status zumofresco"
echo ""
echo -e "${YELLOW}  🔴 Vulnerabilidades XSS:${NC}"
echo -e "     Reflejada: http://${IP}:5000/buscar?q=<script>alert('XSS')</script>"
echo -e "     Almacenada: Comentarios en detalle de producto"
echo ""
echo -e "  📊 Los logs en /opt/zumofresco/logs/ están listos para Filebeat → ELK"
echo ""
