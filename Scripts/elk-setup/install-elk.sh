#!/bin/bash
# ══════════════════════════════════════════════════════════════
# ELK Stack — Instalación con paquetes .deb desde elastic.co
# Elasticsearch + Logstash + Kibana para el lab ZumoFresco
# Ejecutar como root o con sudo en Ubuntu
# ══════════════════════════════════════════════════════════════

set -e

# ─── VERSIÓN (cambia aquí si quieres otra) ──────────────────
ELK_VERSION="8.17.0"
# ────────────────────────────────────────────────────────────

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

BASE_URL="https://artifacts.elastic.co/downloads"
DEB_DIR="/tmp/elk-debs"

echo -e "${CYAN}"
echo "  ══════════════════════════════════════════════════"
echo "   📊 ELK Stack ${ELK_VERSION} — Instalación con .deb"
echo "   Elasticsearch + Logstash + Kibana"
echo "  ══════════════════════════════════════════════════"
echo -e "${NC}"

# ─── Verificaciones previas ─────────────────────────────────
echo -e "${YELLOW}[0/7] Verificando requisitos...${NC}"

TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM_MB" -lt 3500 ]; then
    echo -e "${RED}⚠️  RAM detectada: ${TOTAL_RAM_MB}MB. ELK necesita mínimo 4GB.${NC}"
    exit 1
fi
echo -e "   RAM: ${TOTAL_RAM_MB}MB ✓"

if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
    echo -e "${RED}⚠️  Este script está diseñado para Ubuntu.${NC}"
    exit 1
fi
echo -e "   Ubuntu detectado ✓"

# ─── 1. Preparar sistema ────────────────────────────────────
echo -e "\n${YELLOW}[1/7] Actualizando sistema e instalando dependencias...${NC}"
apt update && apt upgrade -y
apt install -y wget curl jq net-tools

mkdir -p "$DEB_DIR"
cd "$DEB_DIR"

# ─── 2. Descargar paquetes .deb ─────────────────────────────
echo -e "\n${YELLOW}[2/7] Descargando paquetes .deb desde artifacts.elastic.co...${NC}"

echo -e "   📦 Elasticsearch ${ELK_VERSION}..."
wget -q --show-progress "${BASE_URL}/elasticsearch/elasticsearch-${ELK_VERSION}-amd64.deb" -O elasticsearch.deb

echo -e "   📦 Kibana ${ELK_VERSION}..."
wget -q --show-progress "${BASE_URL}/kibana/kibana-${ELK_VERSION}-amd64.deb" -O kibana.deb

echo -e "   📦 Logstash ${ELK_VERSION}..."
wget -q --show-progress "${BASE_URL}/logstash/logstash-${ELK_VERSION}-amd64.deb" -O logstash.deb

echo -e "   ✓ Descargas completadas"
ls -lh "$DEB_DIR"/*.deb

# ─── 3. Instalar Elasticsearch ──────────────────────────────
echo -e "\n${YELLOW}[3/7] Instalando Elasticsearch...${NC}"
dpkg -i elasticsearch.deb || apt install -f -y

cat > /etc/elasticsearch/elasticsearch.yml << 'EOF'
# ═══ Elasticsearch — ZumoFresco Lab ═══
cluster.name: zumofresco-lab
node.name: elk-node-1

network.host: 0.0.0.0
http.port: 9200

discovery.type: single-node

# Seguridad desactivada para el lab (NO hacer en producción)
xpack.security.enabled: false
xpack.security.enrollment.enabled: false
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false

path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
EOF

HEAP_SIZE="2g"
if [ "$TOTAL_RAM_MB" -ge 8000 ]; then
    HEAP_SIZE="4g"
elif [ "$TOTAL_RAM_MB" -ge 6000 ]; then
    HEAP_SIZE="3g"
fi

mkdir -p /etc/elasticsearch/jvm.options.d
cat > /etc/elasticsearch/jvm.options.d/heap.options << EOF
-Xms${HEAP_SIZE}
-Xmx${HEAP_SIZE}
EOF

echo -e "   Heap configurado: ${HEAP_SIZE}"

systemctl daemon-reload
systemctl enable elasticsearch
systemctl start elasticsearch

echo -n "   Esperando a Elasticsearch"
for i in $(seq 1 30); do
    if curl -s http://localhost:9200 > /dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 3
done

if curl -s http://localhost:9200 > /dev/null 2>&1; then
    echo -e "   ${GREEN}Elasticsearch OK${NC} — $(curl -s http://localhost:9200 | jq -r '.version.number' 2>/dev/null)"
else
    echo -e "   ${RED}No responde. Revisa: journalctl -u elasticsearch${NC}"
fi

# ─── 4. Instalar Kibana ─────────────────────────────────────
echo -e "\n${YELLOW}[4/7] Instalando Kibana...${NC}"
dpkg -i kibana.deb || apt install -f -y

cat > /etc/kibana/kibana.yml << 'EOF'
# ═══ Kibana — ZumoFresco Lab ═══
server.port: 5601
server.host: "0.0.0.0"
server.name: "zumofresco-kibana"

elasticsearch.hosts: ["http://localhost:9200"]

i18n.locale: "es"

logging.root.level: info
EOF

systemctl enable kibana
systemctl start kibana

echo -n "   Esperando a Kibana"
for i in $(seq 1 40); do
    if curl -s http://localhost:5601/api/status > /dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 3
done
echo -e "   ${GREEN}Kibana OK${NC}"

# ─── 5. Instalar Logstash ───────────────────────────────────
echo -e "\n${YELLOW}[5/7] Instalando Logstash...${NC}"
dpkg -i logstash.deb || apt install -f -y

cat > /etc/logstash/conf.d/zumofresco.conf << 'PIPELINE'
# ═══ Logstash Pipeline — ZumoFresco ═══

input {
  beats {
    port => 5044
  }
}

filter {

  if [fields][log_type] == "access" {

    mutate {
      add_field => { "log_source" => "zumofresco-access" }
    }

    if [query_string] =~ "(?i)script" {
      mutate { add_tag => ["xss_detected"] add_field => { "attack_type" => "xss" "severity" => "high" } }
    }

    if [query_string] =~ "(?i)onerror" {
      mutate { add_tag => ["xss_detected"] add_field => { "attack_type" => "xss" "severity" => "high" } }
    }

    if [query_string] =~ "(?i)onload" {
      mutate { add_tag => ["xss_detected"] add_field => { "attack_type" => "xss" "severity" => "high" } }
    }

    if [query_string] =~ "(?i)onclick" {
      mutate { add_tag => ["xss_detected"] add_field => { "attack_type" => "xss" "severity" => "high" } }
    }

    if [query_string] =~ "(?i)onmouseover" {
      mutate { add_tag => ["xss_detected"] add_field => { "attack_type" => "xss" "severity" => "high" } }
    }

    if [query_string] =~ "(?i)javascript" {
      mutate { add_tag => ["xss_detected"] add_field => { "attack_type" => "xss" "severity" => "high" } }
    }

    if [query_string] =~ "(?i)iframe" {
      mutate { add_tag => ["xss_detected"] add_field => { "attack_type" => "xss" "severity" => "high" } }
    }

    if [query_string] =~ "(?i)document.cookie" {
      mutate { add_tag => ["xss_detected"] add_field => { "attack_type" => "xss" "severity" => "high" } }
    }

    if [query_string] =~ "(?i)alert\(" {
      mutate { add_tag => ["xss_detected"] add_field => { "attack_type" => "xss" "severity" => "high" } }
    }

    if [query_string] =~ "(?i)eval\(" {
      mutate { add_tag => ["xss_detected"] add_field => { "attack_type" => "xss" "severity" => "high" } }
    }

    if [query_string] =~ "(?i)fetch\(" {
      mutate { add_tag => ["xss_detected"] add_field => { "attack_type" => "xss" "severity" => "high" } }
    }

    if [timestamp] {
      date {
        match => [ "timestamp", "ISO8601" ]
        target => "@timestamp"
      }
    }

    if [user_agent] {
      useragent {
        source => "user_agent"
        target => "ua"
      }
    }
  }

  if [fields][log_type] == "application" {

    grok {
      match => { "message" => "%{TIMESTAMP_ISO8601:log_timestamp} \[%{LOGLEVEL:log_level}\] %{GREEDYDATA:log_message}" }
    }

    mutate {
      add_field => { "log_source" => "zumofresco-app" }
    }

    if [log_message] =~ "(?i)script" {
      mutate { add_tag => ["xss_detected"] add_field => { "attack_type" => "xss" "severity" => "high" } }
    }

    if [log_message] =~ "Nuevo comentario" {
      mutate { add_tag => ["comment_event"] }
    }

    if [log_message] =~ "Nuevo pedido" {
      mutate { add_tag => ["order_event"] }
    }
  }

  mutate {
    remove_field => [ "agent", "ecs", "input", "log" ]
  }
}

output {
  if "xss_detected" in [tags] {
    elasticsearch {
      hosts => ["http://localhost:9200"]
      index => "zumofresco-attacks-%{+YYYY.MM.dd}"
    }
  }

  elasticsearch {
    hosts => ["http://localhost:9200"]
    index => "zumofresco-logs-%{+YYYY.MM.dd}"
  }
}

PIPELINE

mkdir -p /etc/logstash/jvm.options.d
cat > /etc/logstash/jvm.options.d/heap.options << 'EOF'
-Xms1g
-Xmx1g
EOF

systemctl enable logstash
systemctl start logstash

echo -n "   Esperando a Logstash (puerto 5044)"
for i in $(seq 1 30); do
    if ss -tlnp | grep -q ':5044'; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 5
done
echo -e "   ${GREEN}Logstash OK${NC}"

# ─── 6. Firewall ────────────────────────────────────────────
echo -e "\n${YELLOW}[6/7] Configurando firewall...${NC}"

if command -v ufw &> /dev/null; then
    ufw allow 9200/tcp comment "Elasticsearch"
    ufw allow 5601/tcp comment "Kibana"
    ufw allow 5044/tcp comment "Logstash Beats"
    echo -e "   Puertos 9200, 5601, 5044 abiertos ✓"
else
    echo -e "   ufw no encontrado — abre los puertos manualmente si usas otro firewall"
fi

# ─── 7. Limpiar .deb ────────────────────────────────────────
echo -e "\n${YELLOW}[7/7] Limpiando paquetes descargados...${NC}"
rm -rf "$DEB_DIR"
echo -e "   ✓ Limpio"

# ─── Resumen ────────────────────────────────────────────────
IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ ELK Stack ${ELK_VERSION} instalado correctamente${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}Servicios:${NC}"
echo -e "  ├── Elasticsearch   http://${IP}:9200   $(systemctl is-active elasticsearch)"
echo -e "  ├── Kibana           http://${IP}:5601   $(systemctl is-active kibana)"
echo -e "  └── Logstash         puerto 5044         $(systemctl is-active logstash)"
echo ""
echo -e "  ${CYAN}Índices que se crearán:${NC}"
echo -e "  ├── zumofresco-logs-*       → Todos los logs"
echo -e "  └── zumofresco-attacks-*    → Solo ataques XSS"
echo ""
echo -e "  ${CYAN}Siguiente paso:${NC}"
echo -e "  Instalar Filebeat en la máquina Debian → apuntar a ${IP}:5044"
echo ""
echo -e "  🌐 Kibana: http://${IP}:5601"
echo ""
