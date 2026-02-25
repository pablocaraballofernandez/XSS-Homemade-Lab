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

## ELK - SIEM instalado  

ELK es un conjunto de herramientas que sirve para recopilar, guardar y visualizar datos o registros (logs) de sistemas informáticos. Está formado por:  
  
· Elasticsearch (almacena y busca datos)  
· Logstash (recoge y procesa datos)  
· Kibana (muestra los datos en gráficos). Se usa principalmente para analizar información y monitorizar sistemas.

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
