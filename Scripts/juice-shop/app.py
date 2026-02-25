#!/usr/bin/env python3
"""
ZumoFresco - Tienda de Zumos Naturales
Aplicación Flask con vulnerabilidad XSS reflejada (lab de ciberseguridad)
"""

from flask import Flask, render_template, request, redirect, url_for, flash, jsonify
from flask import Markup
import sqlite3
import os
import logging
from logging.handlers import RotatingFileHandler
from datetime import datetime

app = Flask(__name__)
app.secret_key = 'zumofresco-secret-key-2024'

# ─── Logging Configuration (para ELK) ───────────────────────────────
LOG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'logs')
os.makedirs(LOG_DIR, exist_ok=True)

# Access log en formato JSON para Filebeat → ELK
access_handler = RotatingFileHandler(
    os.path.join(LOG_DIR, 'access.log'),
    maxBytes=10_000_000,
    backupCount=5
)
access_handler.setLevel(logging.INFO)

# App log para errores y eventos
app_handler = RotatingFileHandler(
    os.path.join(LOG_DIR, 'app.log'),
    maxBytes=10_000_000,
    backupCount=5
)
app_handler.setLevel(logging.DEBUG)
app_handler.setFormatter(logging.Formatter(
    '%(asctime)s [%(levelname)s] %(message)s'
))

access_logger = logging.getLogger('access')
access_logger.setLevel(logging.INFO)
access_logger.addHandler(access_handler)

app.logger.addHandler(app_handler)
app.logger.setLevel(logging.DEBUG)

# ─── Database ────────────────────────────────────────────────────────
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zumos.db')

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    cursor = conn.cursor()

    cursor.execute('''
        CREATE TABLE IF NOT EXISTS productos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            descripcion TEXT,
            precio REAL NOT NULL,
            imagen TEXT,
            categoria TEXT,
            ingredientes TEXT,
            destacado INTEGER DEFAULT 0
        )
    ''')

    cursor.execute('''
        CREATE TABLE IF NOT EXISTS pedidos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre_cliente TEXT NOT NULL,
            email TEXT NOT NULL,
            producto_id INTEGER,
            cantidad INTEGER DEFAULT 1,
            comentario TEXT,
            fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (producto_id) REFERENCES productos(id)
        )
    ''')

    cursor.execute('''
        CREATE TABLE IF NOT EXISTS comentarios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            producto_id INTEGER,
            autor TEXT NOT NULL,
            texto TEXT NOT NULL,
            fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (producto_id) REFERENCES productos(id)
        )
    ''')

    # Insertar productos de ejemplo
    cursor.execute('SELECT COUNT(*) FROM productos')
    if cursor.fetchone()[0] == 0:
        productos = [
            ('Zumo de Naranja Valencia', 'Naranjas frescas de Valencia, exprimidas al momento. Vitamina C pura.',
             3.50, 'naranja.jpg', 'Cítricos', 'Naranja Valencia 100%', 1),
            ('Smoothie Tropical', 'Explosión de sabor tropical con mango, piña y maracuyá.',
             4.50, 'tropical.jpg', 'Smoothies', 'Mango, Piña, Maracuyá, Yogur natural', 1),
            ('Zumo Verde Detox', 'Depura tu cuerpo con este zumo de espinacas, manzana y jengibre.',
             4.00, 'verde.jpg', 'Detox', 'Espinaca, Manzana verde, Jengibre, Limón', 1),
            ('Limonada de Fresa', 'Refrescante limonada casera con fresas de temporada.',
             3.00, 'fresa.jpg', 'Limonadas', 'Fresa, Limón, Azúcar de caña, Hierbabuena', 0),
            ('Zumo de Zanahoria y Naranja', 'Boost de betacarotenos para tu piel.',
             3.50, 'zanahoria.jpg', 'Salud', 'Zanahoria, Naranja, Cúrcuma', 0),
            ('Batido de Açaí', 'Superalimento brasileño cargado de antioxidantes.',
             5.50, 'acai.jpg', 'Superfoods', 'Açaí, Plátano, Arándanos, Granola', 1),
            ('Agua de Coco Fresca', 'Directa del coco, hidratación natural.',
             3.00, 'coco.jpg', 'Natural', 'Agua de coco 100%', 0),
            ('Zumo de Remolacha Power', 'El favorito de los deportistas. Potencia pura.',
             4.00, 'remolacha.jpg', 'Deportivo', 'Remolacha, Manzana, Zanahoria, Jengibre', 0),
            ('Smoothie de Mango Lassi', 'Inspirado en la India, cremoso y especiado.',
             4.50, 'mango.jpg', 'Smoothies', 'Mango, Yogur, Cardamomo, Miel', 0),
            ('Zumo de Sandía y Menta', 'El rey del verano. Refrescante al máximo.',
             3.50, 'sandia.jpg', 'Refrescantes', 'Sandía, Menta fresca, Lima', 1),
        ]
        cursor.executemany(
            'INSERT INTO productos (nombre, descripcion, precio, imagen, categoria, ingredientes, destacado) VALUES (?, ?, ?, ?, ?, ?, ?)',
            productos
        )

    conn.commit()
    conn.close()

# ─── Middleware: Log de acceso en JSON ──────────────────────────────
@app.before_request
def log_request():
    import json
    log_data = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "method": request.method,
        "path": request.path,
        "query_string": request.query_string.decode('utf-8', errors='replace'),
        "remote_addr": request.remote_addr,
        "user_agent": request.headers.get('User-Agent', ''),
        "referer": request.headers.get('Referer', ''),
        "host": request.host
    }
    access_logger.info(json.dumps(log_data))

# ─── Rutas ───────────────────────────────────────────────────────────

@app.route('/')
def index():
    conn = get_db()
    destacados = conn.execute(
        'SELECT * FROM productos WHERE destacado = 1 ORDER BY RANDOM() LIMIT 4'
    ).fetchall()
    categorias = conn.execute(
        'SELECT DISTINCT categoria FROM productos ORDER BY categoria'
    ).fetchall()
    conn.close()
    return render_template('index.html', destacados=destacados, categorias=categorias)


@app.route('/productos')
def productos():
    categoria = request.args.get('categoria', '')
    conn = get_db()
    if categoria:
        items = conn.execute(
            'SELECT * FROM productos WHERE categoria = ? ORDER BY nombre', (categoria,)
        ).fetchall()
    else:
        items = conn.execute('SELECT * FROM productos ORDER BY nombre').fetchall()
    categorias = conn.execute(
        'SELECT DISTINCT categoria FROM productos ORDER BY categoria'
    ).fetchall()
    conn.close()
    return render_template('productos.html', productos=items, categorias=categorias, categoria_actual=categoria)


@app.route('/producto/<int:producto_id>')
def producto_detalle(producto_id):
    conn = get_db()
    producto = conn.execute('SELECT * FROM productos WHERE id = ?', (producto_id,)).fetchone()
    comentarios = conn.execute(
        'SELECT * FROM comentarios WHERE producto_id = ? ORDER BY fecha DESC', (producto_id,)
    ).fetchall()
    conn.close()
    if not producto:
        flash('Producto no encontrado', 'error')
        return redirect(url_for('productos'))
    return render_template('detalle.html', producto=producto, comentarios=comentarios)


# ╔══════════════════════════════════════════════════════════════════╗
# ║  🔴 VULNERABILIDAD XSS REFLEJADA - BÚSQUEDA                    ║
# ║  El parámetro 'q' se renderiza sin escapar en el template       ║
# ║  usando |safe o Markup(), permitiendo inyección de scripts      ║
# ╚══════════════════════════════════════════════════════════════════╝
@app.route('/buscar')
def buscar():
    query = request.args.get('q', '')
    conn = get_db()
    resultados = []
    if query:
        # Búsqueda legítima en la BD
        resultados = conn.execute(
            "SELECT * FROM productos WHERE nombre LIKE ? OR descripcion LIKE ? OR ingredientes LIKE ?",
            (f'%{query}%', f'%{query}%', f'%{query}%')
        ).fetchall()
        app.logger.info(f"Búsqueda realizada: '{query}' - {len(resultados)} resultados")
    conn.close()

    # ⚠️ VULNERABLE: query se pasa sin sanitizar al template
    # El template usa {{ query_raw|safe }} para renderizarlo
    return render_template('buscar.html', resultados=resultados, query_raw=query)


# ╔══════════════════════════════════════════════════════════════════╗
# ║  🔴 VULNERABILIDAD XSS ALMACENADA - COMENTARIOS                ║
# ║  Los comentarios se guardan y muestran sin sanitizar            ║
# ╚══════════════════════════════════════════════════════════════════╝
@app.route('/comentar/<int:producto_id>', methods=['POST'])
def comentar(producto_id):
    autor = request.form.get('autor', 'Anónimo')
    texto = request.form.get('texto', '')

    if texto:
        conn = get_db()
        # ⚠️ VULNERABLE: se guarda sin sanitizar
        conn.execute(
            'INSERT INTO comentarios (producto_id, autor, texto) VALUES (?, ?, ?)',
            (producto_id, autor, texto)
        )
        conn.commit()
        conn.close()
        app.logger.info(f"Nuevo comentario en producto {producto_id} por '{autor}'")
        flash('¡Comentario añadido!', 'success')
    else:
        flash('El comentario no puede estar vacío', 'error')

    return redirect(url_for('producto_detalle', producto_id=producto_id))


@app.route('/pedido', methods=['POST'])
def hacer_pedido():
    nombre = request.form.get('nombre', '')
    email = request.form.get('email', '')
    producto_id = request.form.get('producto_id', 0, type=int)
    cantidad = request.form.get('cantidad', 1, type=int)
    comentario = request.form.get('comentario', '')

    if nombre and email and producto_id:
        conn = get_db()
        conn.execute(
            'INSERT INTO pedidos (nombre_cliente, email, producto_id, cantidad, comentario) VALUES (?, ?, ?, ?, ?)',
            (nombre, email, producto_id, cantidad, comentario)
        )
        conn.commit()
        conn.close()
        app.logger.info(f"Nuevo pedido: {nombre} ({email}) - Producto #{producto_id} x{cantidad}")
        flash('¡Pedido realizado con éxito! 🎉', 'success')
    else:
        flash('Por favor, completa todos los campos obligatorios', 'error')

    return redirect(url_for('producto_detalle', producto_id=producto_id))


@app.route('/nosotros')
def nosotros():
    return render_template('nosotros.html')


@app.route('/contacto', methods=['GET', 'POST'])
def contacto():
    if request.method == 'POST':
        flash('¡Mensaje enviado! Te contactaremos pronto.', 'success')
        return redirect(url_for('contacto'))
    return render_template('contacto.html')


# ─── API endpoints (para posible uso futuro) ────────────────────────
@app.route('/api/productos')
def api_productos():
    conn = get_db()
    productos = conn.execute('SELECT * FROM productos').fetchall()
    conn.close()
    return jsonify([dict(p) for p in productos])


# ─── Inicialización ─────────────────────────────────────────────────
if __name__ == '__main__':
    init_db()
    app.run(host='0.0.0.0', port=5000, debug=True)
