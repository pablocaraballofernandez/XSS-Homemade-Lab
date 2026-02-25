<div align="center">

#  ZumoFresco

### Laboratorio de ciberseguridad

Laboratorio de ciberseguridad basado en una tienda de zumos ficticia con vulnerabilidades XSS intencionadas, monitorizada con ELK Stack para detección y análisis de ataques en tiempo real.

[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![Flask](https://img.shields.io/badge/Flask-3.0-000000?style=flat-square&logo=flask&logoColor=white)](https://flask.palletsprojects.com)
[![Debian](https://img.shields.io/badge/Debian%2012-A81D33?style=flat-square&logo=debian&logoColor=white)](https://debian.org)
[![ELK](https://img.shields.io/badge/ELK%20Stack-8.x-005571?style=flat-square&logo=elastic&logoColor=white)](https://elastic.co)

</div>

---

##  Idea del proyecto

La idea es simple: montar un entorno realista donde convivan una aplicación web vulnerable y un sistema SIEM que la monitorice, simulando un escenario típico de Blue Team / SOC.

La web (**ZumoFresco**) corre en una máquina Debian y tiene vulnerabilidades XSS reales que se pueden explotar desde el navegador. Mientras tanto, una máquina Ubuntu con ELK Stack recoge los logs en tiempo real, permitiendo crear dashboards y alertas para detectar esos ataques.

##  Arquitectura

```
┌──────────────────────────────────┐       ┌──────────────────────────────────┐
│         DEBIAN 12                │       │        UBUNTU 22.04             │
│                                  │       │                                  │
│   ZumoFresco (Flask + Gunicorn)  │       │   Elasticsearch         :9200   │
│   ├── Puerto 5000                │       │   Logstash              :5044   │
│   ├── SQLite                     │       │   Kibana                :5601   │
│   └── Logs JSON                  │       │                                  │
│                                  │       │   Dashboards de detección XSS   │
│   Filebeat ──────────────────────┼──────▶│   Alertas automáticas           │
│                                  │       │                                  │
└──────────────────────────────────┘       └──────────────────────────────────┘
```

Ambas máquinas virtuales corren en local (VirtualBox) dentro de la misma red interna.

##  La aplicación — ZumoFresco

Una tienda online de zumos naturales con diseño moderno, catálogo de productos, sistema de pedidos y sección de comentarios. Construida con Flask, Jinja2 y SQLite.

### Funcionalidades

- Página de inicio con productos destacados y categorías
- Catálogo completo con filtros por categoría
- Detalle de producto con formulario de pedido
- Sistema de comentarios por producto
- Buscador de zumos
- Página de contacto y "sobre nosotros"
- Logging de cada request en formato JSON (preparado para ELK)

##  Vulnerabilidades

El lab incluye dos tipos de XSS intencionadas:

### Reflected XSS — Búsqueda

El buscador de zumos refleja el input del usuario sin sanitizar. El parámetro `q` se renderiza con el filtro `|safe` de Jinja2, desactivando el auto-escape y permitiendo inyectar HTML y JavaScript directamente desde la URL.

```
/buscar?q=<script>alert('XSS')</script>
```

### Stored XSS — Comentarios

Los comentarios de los productos se almacenan en la base de datos sin ningún tipo de sanitización y se muestran en la página con `|safe`. Un atacante puede dejar un comentario con código malicioso que se ejecutará para todos los visitantes de ese producto.

### Comparativa

| Tipo | Vector | Persistencia | Alcance |
|------|--------|-------------|---------|
| Reflected | URL con payload en `?q=` | No | Solo quien abra el enlace |
| Stored | Comentario malicioso | Sí (en base de datos) | Todos los visitantes |

## 📊 Detección con ELK

Los logs de ZumoFresco se generan en JSON y se envían mediante Filebeat al stack ELK en la máquina Ubuntu. Esto permite:

- **Visualizar** todo el tráfico HTTP en Kibana en tiempo real
- **Detectar** payloads XSS en query strings y cuerpos de petición
- **Crear alertas** automáticas cuando se identifiquen patrones sospechosos (`<script>`, `onerror`, `document.cookie`, etc.)
- **Analizar** el comportamiento del atacante con filtros por IP, User-Agent y rutas

### Ejemplo de log capturado

```json
{
  "timestamp": "2024-12-15T10:30:00.000Z",
  "method": "GET",
  "path": "/buscar",
  "query_string": "q=<script>alert('XSS')</script>",
  "remote_addr": "192.168.56.1",
  "user_agent": "Mozilla/5.0 (X11; Linux x86_64)...",
  "host": "192.168.56.10:5000"
}
```

##  Tech Stack

| Componente | Tecnología |
|------------|------------|
| Aplicación web | Python, Flask, Jinja2 |
| Base de datos | SQLite |
| Servidor | Gunicorn + systemd |
| VM web | Debian 12 |
| SIEM | Elasticsearch + Logstash + Kibana 8.x |
| Collector | Filebeat |
| VM SIEM | Ubuntu 22.04 |
| Virtualización | VirtualBox |

##  Estructura del proyecto

```
zumofresco/
├── app.py                  # Aplicación Flask con rutas y lógica
├── requirements.txt        # Dependencias Python
├── install.sh              # Script de despliegue para Debian
├── logs/                   # Logs JSON para Filebeat → ELK
│   ├── access.log
│   └── app.log
├── static/css/
│   └── style.css           # Diseño con Playfair Display + DM Sans
└── templates/
    ├── base.html            
    ├── index.html           # Home
    ├── productos.html       # Catálogo
    ├── detalle.html         # Detalle + comentarios [Stored XSS]
    ├── buscar.html          # Búsqueda [Reflected XSS]
    ├── nosotros.html       
    └── contacto.html       
```

##  Objetivos de aprendizaje

- Entender cómo funcionan las vulnerabilidades XSS (reflejada y almacenada)
- Desplegar y configurar un stack ELK completo
- Conectar fuentes de log con Filebeat y Logstash
- Crear dashboards y visualizaciones en Kibana orientadas a seguridad
- Diseñar reglas de detección para ataques web comunes
- Practicar el flujo completo de ataque → detección → análisis

##  Disclaimer

Este proyecto es **exclusivamente educativo**. Las vulnerabilidades son intencionadas y el entorno está diseñado para ejecutarse de forma aislada en máquinas virtuales locales. No expongas esta aplicación a Internet ni la utilices contra sistemas sin autorización.

---
