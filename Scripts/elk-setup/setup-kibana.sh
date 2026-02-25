#!/bin/bash
# ══════════════════════════════════════════════════════════════
# Kibana — Configuración de Data Views y Búsquedas guardadas
# Ejecutar DESPUÉS de que lleguen los primeros logs
# ══════════════════════════════════════════════════════════════

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

KIBANA_URL="http://localhost:5601"

echo -e "${CYAN}"
echo "  ══════════════════════════════════════════════════"
echo "   📊 Kibana — Setup de dashboards ZumoFresco"
echo "  ══════════════════════════════════════════════════"
echo -e "${NC}"

# Esperar a que Kibana esté listo
echo -n "Esperando a Kibana..."
for i in $(seq 1 30); do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${KIBANA_URL}/api/status")
    if [ "$STATUS" = "200" ]; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 3
done

# ─── 1. Crear Data View para todos los logs ────────────────
echo -e "\n${YELLOW}[1/4] Creando Data View: zumofresco-logs-*${NC}"

curl -s -X POST "${KIBANA_URL}/api/data_views/data_view" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "data_view": {
      "title": "zumofresco-logs-*",
      "name": "ZumoFresco - Todos los logs",
      "timeFieldName": "@timestamp"
    }
  }' > /dev/null 2>&1 && echo -e "   ✓ Data View logs creado" || echo -e "   ⚠️  Ya existía o error"

# ─── 2. Crear Data View para ataques ───────────────────────
echo -e "\n${YELLOW}[2/4] Creando Data View: zumofresco-attacks-*${NC}"

curl -s -X POST "${KIBANA_URL}/api/data_views/data_view" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "data_view": {
      "title": "zumofresco-attacks-*",
      "name": "ZumoFresco - Ataques XSS",
      "timeFieldName": "@timestamp"
    }
  }' > /dev/null 2>&1 && echo -e "   ✓ Data View ataques creado" || echo -e "   ⚠️  Ya existía o error"

# ─── 3. Crear búsquedas guardadas útiles ───────────────────
echo -e "\n${YELLOW}[3/4] Verificando índices en Elasticsearch...${NC}"

# Comprobar que hay datos
INDICES=$(curl -s "http://localhost:9200/_cat/indices/zumofresco-*?h=index,docs.count" 2>/dev/null)
if [ -n "$INDICES" ]; then
    echo -e "   Índices encontrados:"
    echo "$INDICES" | while read line; do
        echo -e "   ├── $line"
    done
else
    echo -e "   ${YELLOW}⚠️  Aún no hay datos. Genera tráfico en ZumoFresco primero.${NC}"
fi

# ─── 4. Mostrar queries útiles ─────────────────────────────
echo -e "\n${YELLOW}[4/4] Queries KQL para usar en Kibana Discover:${NC}"

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Queries de detección XSS para Kibana${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}1. Todos los ataques XSS detectados:${NC}"
echo '     tags: "xss_detected"'
echo ""
echo -e "  ${GREEN}2. Payloads <script> en búsquedas:${NC}"
echo '     query_string: *<script* AND path: "/buscar"'
echo ""
echo -e "  ${GREEN}3. Event handlers sospechosos:${NC}"
echo '     query_string: (*onerror* OR *onload* OR *onclick* OR *onmouseover*)'
echo ""
echo -e "  ${GREEN}4. Intentos de robo de cookies:${NC}"
echo '     query_string: *document.cookie*'
echo ""
echo -e "  ${GREEN}5. Protocolo javascript: en URLs:${NC}"
echo '     query_string: *javascript:*'
echo ""
echo -e "  ${GREEN}6. Inyección de iframes/embeds:${NC}"
echo '     query_string: (*<iframe* OR *<embed* OR *<object*)'
echo ""
echo -e "  ${GREEN}7. Exfiltración vía fetch/XMLHttpRequest:${NC}"
echo '     query_string: (*fetch\(* OR *XMLHttpRequest*)'
echo ""
echo -e "  ${GREEN}8. Todas las búsquedas realizadas:${NC}"
echo '     tags: "search_event"'
echo ""
echo -e "  ${GREEN}9. Nuevos comentarios (posible stored XSS):${NC}"
echo '     tags: "comment_event"'
echo ""
echo -e "  ${GREEN}10. Alta severidad:${NC}"
echo '     severity: "high"'
echo ""

echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ Setup de Kibana completado${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  🌐 Accede a Kibana: ${KIBANA_URL}"
echo -e "  📊 Ve a Discover y selecciona 'ZumoFresco - Todos los logs'"
echo -e "  🔴 Para ver solo ataques: selecciona 'ZumoFresco - Ataques XSS'"
echo ""
