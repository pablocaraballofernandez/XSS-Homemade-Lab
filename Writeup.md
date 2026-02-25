# 🍊 ZumoFresco — Memoria del Laboratorio

## Índice

1. [Introducción](#1-introducción)
2. [Montaje de la aplicación web](#2-montaje-de-la-aplicación-web)
3. [Montaje del stack ELK](#3-montaje-del-stack-elk)
4. [Conexión Filebeat → Logstash](#4-conexión-filebeat--logstash)
5. [Explotación de vulnerabilidades XSS](#5-explotación-de-vulnerabilidades-xss)
6. [¿Qué es XSS y cómo prevenirlo?](#6-qué-es-xss-y-cómo-prevenirlo)

---

## 1. Introducción

El objetivo de este laboratorio es montar un entorno realista donde convivan una aplicación web vulnerable y un sistema SIEM que la monitorice, simulando un escenario típico de Blue Team en un SOC (Security Operations Center).

El lab se compone de dos máquinas virtuales en VirtualBox conectadas por adaptador puente dentro de la misma red local:

- **Debian 12 (ZumoFresco):** Aloja la aplicación web vulnerable, una tienda ficticia de zumos naturales construida con Flask y SQLite. Incluye dos vulnerabilidades XSS intencionadas (reflejada y almacenada) y genera logs en formato JSON preparados para su análisis.

- **Ubuntu 22.04 (ELK Stack):** Ejecuta Elasticsearch, Logstash y Kibana en su versión 8.17.0. Recibe los logs de ZumoFresco a través de Filebeat, los procesa con un pipeline de detección de patrones XSS y los indexa para su visualización en Kibana.

---

## 2. Montaje de la aplicación web

### 2.1. Instalación de ZumoFresco en Debian

El despliegue de ZumoFresco se realiza mediante un script automatizado (`install.sh`) que ejecuta las siguientes acciones:

- Instalación de Python 3, pip y herramientas de compilación.
- Creación del usuario de sistema `zumofresco` y del directorio de la aplicación en `/opt/zumofresco`.
- Configuración de un entorno virtual Python (venv) e instalación de las dependencias: Flask 3.0 y Gunicorn 21.2.
- Inicialización de la base de datos SQLite con 10 productos precargados (zumos de distintas categorías: cítricos, smoothies, detox, superfoods y salud).
- Creación de un servicio systemd (`zumofresco.service`) para que la aplicación arranque automáticamente con el sistema.

El script se ejecuta como root desde el directorio del proyecto:

```bash
chmod +x install.sh
./install.sh
```

La instalación finaliza mostrando un resumen con la IP de acceso, la ruta de la aplicación y las rutas de los logs.

![Instalación de ZumoFresco en Debian](/Images/MontajeWeb/1.jpg)

### 2.2. Verificación de la aplicación

Una vez completada la instalación, se accede a la web desde el navegador del equipo host a través de la IP de la máquina Debian en el puerto 5000.

![Página principal de ZumoFresco](/Images/MontajeWeb/2.jpg)

La aplicación genera dos ficheros de log en `/opt/zumofresco/logs/`:

- **access.log:** Registra cada petición HTTP en formato JSON (timestamp, método, ruta, query string, IP de origen, User-Agent y referer).
- **app.log:** Registra eventos de la aplicación como búsquedas realizadas, pedidos y comentarios nuevos.

Este formato JSON es clave para que Filebeat pueda enviar los logs al ELK Stack sin necesidad de parseo adicional.

---

## 3. Montaje del stack ELK

### 3.1. Instalación de Elasticsearch, Logstash y Kibana

El stack ELK se instala en la máquina Ubuntu mediante el script `install-elk.sh`, que descarga los paquetes `.deb` directamente desde `artifacts.elastic.co` y los instala con `dpkg -i`. El script realiza las siguientes acciones:

- Verificación de requisitos (mínimo 4 GB de RAM, sistema Ubuntu).
- Descarga de los tres paquetes `.deb` de la versión 8.17.0: Elasticsearch, Kibana y Logstash.
- Instalación y configuración de **Elasticsearch**: modo single-node, seguridad xpack desactivada para el entorno de laboratorio, heap de la JVM ajustado dinámicamente según la RAM disponible.
- Instalación y configuración de **Kibana**: escucha en todas las interfaces en el puerto 5601, idioma configurado en español, conexión a Elasticsearch local.
- Instalación y configuración de **Logstash**: pipeline personalizado que recibe logs por Beats en el puerto 5044, detecta patrones XSS mediante expresiones regulares y envía los resultados a dos índices de Elasticsearch (`zumofresco-logs-*` para todos los logs y `zumofresco-attacks-*` exclusivamente para los ataques detectados).
- Apertura de puertos en el firewall (9200, 5601, 5044).

```bash
chmod +x install-elk.sh
./install-elk.sh
```

![Instalación del stack ELK en Ubuntu](/Images/MontajeELK/1.jpg)

### 3.2. Pipeline de detección XSS en Logstash

El componente más importante de la configuración de Logstash es el pipeline de detección. Este analiza cada log entrante y busca patrones sospechosos en el campo `query_string` mediante expresiones regulares case-insensitive. Los patrones detectados incluyen:

- Etiquetas `<script>` y protocolo `javascript:`
- Event handlers HTML: `onerror`, `onload`, `onclick`, `onmouseover`
- Etiquetas de inyección: `<iframe>`, `<embed>`, `<svg>`
- Funciones JavaScript peligrosas: `alert()`, `eval()`, `fetch()`
- Acceso a datos sensibles: `document.cookie`

---

## 4. Conexión Filebeat → Logstash

### 4.1. Instalación de Filebeat en Debian

Para conectar los logs de ZumoFresco con el ELK Stack, se instala Filebeat en la máquina Debian mediante el script `install-filebeat.sh`. Este descarga el paquete `.deb` de Filebeat 8.17.0 desde `artifacts.elastic.co`, lo instala y lo configura para:

- Monitorizar tres ficheros de log: `access.log` (JSON), `app.log` (texto plano) y `gunicorn-access.log`.
- Enviar los logs al Logstash de la máquina Ubuntu por el puerto 5044.
- Etiquetar cada input con su tipo (`access`, `application`, `gunicorn`) para que el pipeline de Logstash los procese correctamente.

```bash
chmod +x install-filebeat.sh
./install-filebeat.sh ip-máquina-kibana-logstash
```

![Instalación de Filebeat en Debian](/Images/MontajeELK/2.jpg)

### 4.2. Verificación de la conexión

La conectividad entre ambas máquinas se verifica con el comando `filebeat test output`, que comprueba la resolución DNS, la conexión TCP y el handshake con Logstash. Una vez confirmada la conexión, cada petición que recibe ZumoFresco se registra en los logs locales, Filebeat los recoge y los envía a Logstash, que los analiza y los indexa en Elasticsearch para su visualización en Kibana.

---

## 5. Explotación de vulnerabilidades XSS

### 5.1. XSS Reflejado — Buscador de zumos

A continuación, se inyecta un payload XSS directamente desde la barra de búsqueda de la web. El payload utilizado es `<script>alert('ZumoFresco Explotado')</script>`. Al ejecutar la búsqueda, el navegador interpreta el código JavaScript inyectado y muestra el alert, confirmando la explotación del XSS reflejado:

![Alert de XSS reflejado ejecutado](/Images/Explotación/3.jpg)

Este tipo de ataque se denomina "reflejado" porque el payload viaja en la petición y se refleja en la respuesta del servidor. Un atacante podría distribuir la URL maliciosa por email, redes sociales o mensajería para que la víctima la abra sin sospechar.

Se puede observar que al inyectar el payload directamente en la URL (`/buscar?q=<script>alert('XSS')</script>`), algunos navegadores modernos bloquean la ejecución del script como medida de protección. Sin embargo, la inyección desde el formulario de búsqueda consigue ejecutar el código sin restricciones:

![Intento de XSS reflejado desde la URL](/Images/Explotación/4.jpg)

### 5.2. XSS Almacenado — Comentarios de productos

La segunda vulnerabilidad se encuentra en el sistema de comentarios de los productos. Los campos de nombre y texto se almacenan en la base de datos SQLite sin ningún tipo de sanitización y se renderizan con el filtro `|safe`.

Un atacante puede publicar un comentario con código malicioso en cualquier producto. A diferencia del XSS reflejado, este payload persiste en la base de datos y se ejecuta automáticamente para todos los visitantes que accedan a la página de ese producto, sin necesidad de que abran un enlace especial.

![Intento de XSS almacenado desde los comentarios](/Images/Explotación/6.jpg)  

![Intento de XSS almacenado desde los comentarios](/Images/Explotación/7.jpg)


### 5.3. Comparativa entre ambos tipos

| Característica | Reflejado | Almacenado |
|---|---|---|
| **Vector** | Parámetro `q` en la URL de búsqueda | Campos del formulario de opiniones |
| **Persistencia** | No persiste, solo activo en la URL | Persiste en base de datos |
| **Alcance** | Solo la víctima que abra el enlace | Todos los visitantes del producto |
| **Peligrosidad** | Media | Alta |
| **Detección** | Visible en query_string del log | Requiere analizar el cuerpo del POST |

### 5.4. Log en Kibana
Una vez realizado los ataques, podemos revisar como ELK recoge los incidentes y observar los sucedido.

![Kibana/log](/Images/Explotación/5.jpg)

---

## 6. ¿Qué es XSS y cómo prevenirlo?

### 6.1. ¿Qué es Cross-Site Scripting (XSS)?

Cross-Site Scripting (XSS) es una vulnerabilidad de seguridad web que permite a un atacante inyectar código JavaScript malicioso en páginas que otros usuarios van a visitar. Se produce cuando una aplicación web incluye datos proporcionados por el usuario en la respuesta HTML sin validarlos ni sanitizarlos correctamente.

Las consecuencias de un ataque XSS exitoso pueden incluir el robo de cookies de sesión (y por tanto el secuestro de cuentas), la redirección a sitios de phishing, la captura de pulsaciones de teclado (keylogging), la modificación del contenido visible de la página o la descarga de malware en el equipo de la víctima.

Existen tres tipos principales:

- **Reflejado (Reflected):** El payload viaja en la petición (normalmente en la URL) y se refleja en la respuesta. Requiere que la víctima abra un enlace manipulado.
- **Almacenado (Stored):** El payload se guarda en el servidor (base de datos, comentarios, foros) y se ejecuta cada vez que un usuario carga la página afectada. Es el más peligroso por su alcance.
- **Basado en DOM (DOM-based):** El payload se ejecuta en el lado del cliente manipulando el DOM del navegador sin que el servidor intervenga en la inyección.

### 6.2. ¿Cómo prevenirlo?

La prevención del XSS requiere aplicar múltiples capas de defensa:

**Escapado de la salida (Output Encoding):** Toda la información procedente del usuario debe escaparse antes de incluirla en el HTML. En Flask con Jinja2, esto se consigue simplemente no utilizando el filtro `|safe`, ya que el motor de plantillas escapa automáticamente las variables por defecto. En el caso concreto de ZumoFresco, bastaría con eliminar el `|safe` de las plantillas `buscar.html` y `detalle.html` para neutralizar ambas vulnerabilidades.

**Validación de la entrada (Input Validation):** Validar y filtrar los datos del usuario en el servidor antes de procesarlos. Rechazar o sanear caracteres especiales de HTML como `<`, `>`, `"`, `'` y `&`. En Python se puede usar `bleach` o `markupsafe` para limpiar el HTML de la entrada.

**Content Security Policy (CSP):** Implementar cabeceras HTTP de Content Security Policy que restrinjan qué scripts puede ejecutar el navegador. Una política como `Content-Security-Policy: script-src 'self'` impide la ejecución de scripts inline inyectados.

**Cabeceras de seguridad HTTP:** Configurar cabeceras adicionales como `X-Content-Type-Options: nosniff` y `X-XSS-Protection: 1; mode=block` para añadir capas extra de protección a nivel de navegador.

**Cookies HttpOnly y Secure:** Marcar las cookies de sesión con los flags `HttpOnly` (impide el acceso desde JavaScript) y `Secure` (solo se envían por HTTPS), de modo que aunque se ejecute un XSS, el atacante no pueda robar la cookie de sesión.

**Uso de frameworks modernos:** Los frameworks web modernos como React, Angular o Vue.js escapan las variables por defecto en sus plantillas, reduciendo significativamente la superficie de ataque. En el backend, frameworks como Django o Flask con Jinja2 también escapan por defecto, siempre que no se desactive manualmente esta protección.

La clave está en no confiar nunca en los datos proporcionados por el usuario y aplicar el principio de defensa en profundidad: aunque una medida falle, las demás capas deben seguir protegiendo la aplicación.
