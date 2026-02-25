#!/bin/bash
# ══════════════════════════════════════════════════════════════
# Filebeat — Instalación con .deb en Debian (máquina ZumoFresco)
# Envía logs al ELK Stack en Ubuntu
# Ejecutar como root o con sudo
# ══════════════════════════════════════════════════════════════

set -e

# ─── VERSIÓN (debe coincidir con la del ELK) ───────────────
ELK_VERSION="8.17.0"
# ────────────────────────────────────────────────────────────

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

BASE_URL="https://artifacts.elastic.co/downloads"

echo -e "${CYAN}"
echo "  ══════════════════════════════════════════════════"
echo "   📤 Filebeat ${ELK_VERSION} — Instalación con .deb"
echo "  ══════════════════════════════════════════════════"
echo -e "${NC}"

# ─── Pedir IP del ELK ──────────────────────────────────────
if [ -z "$1" ]; then
    echo -n "Introduce la IP de tu máquina Ubuntu (ELK): "
    read ELK_IP
else
    ELK_IP="$1"
fi

if [ -z "$ELK_IP" ]; then
    echo -e "${RED}Error: necesitas indicar la IP del ELK${NC}"
    echo "Uso: sudo ./install-filebeat.sh <IP_ELK>"
    exit 1
fi

echo -e "   ELK target: ${ELK_IP}:5044"

# ─── 1. Descargar .deb ─────────────────────────────────────
echo -e "\n${YELLOW}[1/3] Descargando Filebeat ${ELK_VERSION}...${NC}"

apt update
apt install -y wget curl

cd /tmp
wget -q --show-progress "${BASE_URL}/beats/filebeat/filebeat-${ELK_VERSION}-amd64.deb" -O filebeat.deb

# ─── 2. Instalar ────────────────────────────────────────────
echo -e "\n${YELLOW}[2/3] Instalando Filebeat...${NC}"
dpkg -i filebeat.deb || apt install -f -y
rm -f /tmp/filebeat.deb

# ─── 3. Configurar ─────────────────────────────────────────
echo -e "\n${YELLOW}[3/3] Configurando Filebeat...${NC}"

cat > /etc/filebeat/filebeat.yml << EOF
# ═══ Filebeat — ZumoFresco → ELK ═══

filebeat.inputs:

  # Log de acceso HTTP (JSON)
  - type: log
    id: zumofresco-access
    enabled: true
    paths:
      - /opt/zumofresco/logs/access.log
    json.keys_under_root: true
    json.add_error_key: true
    json.overwrite_keys: true
    fields:
      app: zumofresco
      log_type: access
    fields_under_root: false

  # Log de la aplicación
  - type: log
    id: zumofresco-app
    enabled: true
    paths:
      - /opt/zumofresco/logs/app.log
    fields:
      app: zumofresco
      log_type: application
    fields_under_root: false

  # Log de Gunicorn
  - type: log
    id: zumofresco-gunicorn
    enabled: true
    paths:
      - /opt/zumofresco/logs/gunicorn-access.log
    fields:
      app: zumofresco
      log_type: gunicorn
    fields_under_root: false

processors:
  - add_host_metadata:
      when.not.contains.tags: forwarded
  - add_fields:
      target: ''
      fields:
        environment: lab
        project: zumofresco

output.logstash:
  hosts: ["${ELK_IP}:5044"]
  bulk_max_size: 2048

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 3
  permissions: 0640
EOF

systemctl enable filebeat
systemctl start filebeat

# ─── Verificar ──────────────────────────────────────────────
sleep 3
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ Filebeat ${ELK_VERSION} instalado y configurado${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}Destino:${NC}           ${ELK_IP}:5044 (Logstash)"
echo ""
echo -e "  ${CYAN}Logs monitorizados:${NC}"
echo -e "  ├── /opt/zumofresco/logs/access.log"
echo -e "  ├── /opt/zumofresco/logs/app.log"
echo -e "  └── /opt/zumofresco/logs/gunicorn-access.log"
echo ""
echo -e "  ${CYAN}Comandos útiles:${NC}"
echo -e "  ├── Estado:    systemctl status filebeat"
echo -e "  ├── Logs:      journalctl -u filebeat -f"
echo -e "  └── Test:      filebeat test output"
echo ""
