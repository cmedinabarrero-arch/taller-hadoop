# -*- coding: utf-8 -*-
"""
Genera los 3 datasets sintéticos del taller. Usa una semilla fija, así que
siempre produce exactamente los mismos archivos.

  textos/texto_0X.txt  -> frases en español (para WordCount)
  logs/access.log      -> logs de un servidor web, 1 semana (horas pico, URLs)
  ventas/ventas.csv    -> ventas de una tienda en ciudades de Colombia

Los archivos ya vienen generados en el proyecto; este script solo sirve
para volver a crearlos (por ejemplo dentro del contenedor nodemanager1):
    docker exec nodemanager1 python3 /workspace/datos/generar_datos.py
Compatible con Python 3.5+.
"""
import datetime
import io
import os
import random

random.seed(2026)
BASE = os.path.dirname(os.path.abspath(__file__))


def guardar(ruta_relativa, lineas):
    ruta = os.path.join(BASE, ruta_relativa)
    if not os.path.isdir(os.path.dirname(ruta)):
        os.makedirs(os.path.dirname(ruta))
    with io.open(ruta, "w", encoding="utf-8", newline="\n") as f:
        for linea in lineas:
            f.write(linea + "\n")
    print("  %-22s %8d líneas  %6.1f MB" % (ruta_relativa, len(lineas),
                                             os.path.getsize(ruta) / 1048576.0))


def elegir_zipf(opciones, s=1.0):
    """Lista de pesos tipo Zipf: el 1º es el más frecuente, el 2º la mitad..."""
    return [1.0 / ((i + 1) ** s) for i in range(len(opciones))]


# ----------------------------------------------------------------------
# 1) Textos para WordCount
# ----------------------------------------------------------------------
def generar_textos():
    palabras = (
        "de la el en y que los las del se un una por con para su al es lo "
        "como más pero sus le ya o este sí porque esta entre cuando muy sin "
        "sobre también me hasta hay donde quien desde todo nos durante todos "
        "datos cali nodo archivo bloque réplica hadoop clúster servidor red "
        "salsa café río ciudad valle estudiante universidad profesor clase "
        "taller memoria disco tarea trabajo sistema información análisis "
        "resultado proceso tiempo día noche música baile gente calle mercado "
        "fruta mango lulo chontaduro pandebono empanada cholado montaña "
        "cerro tres cruces farallones sol lluvia brisa domingo viernes "
        "procesa guarda lee escribe divide cuenta analiza baila camina "
        "estudia aprende enseña corre falla recupera replica distribuye "
        "rápido lento grande pequeño nuevo viejo caliente bonito difícil "
        "fácil importante distribuido paralelo tolerante seguro alegre"
    ).split()
    pesos = elegir_zipf(palabras, 1.05)
    for n in range(1, 4):
        lineas = []
        for _ in range(22000):
            largo = random.randint(6, 16)
            lineas.append(" ".join(elegir(palabras, pesos, k=largo)))
        guardar("textos/texto_%02d.txt" % n, lineas)


def _choices35(opciones, pesos, k):
    """random.choices no existe en Python 3.5: versión sencilla."""
    total = sum(pesos)
    res = []
    for _ in range(k):
        r = random.uniform(0, total)
        acum = 0
        for o, p in zip(opciones, pesos):
            acum += p
            if r <= acum:
                res.append(o)
                break
        else:
            res.append(opciones[-1])
    return res


def elegir(opciones, pesos, k=1):
    if hasattr(random, "choices"):
        return random.choices(opciones, weights=pesos, k=k)
    return _choices35(opciones, pesos, k)


# ----------------------------------------------------------------------
# 2) Logs de acceso web (formato Apache "common log")
#    IP - - [dd/Mon/aaaa:HH:MM:SS -0500] "MÉTODO URL HTTP/1.1" status bytes
# ----------------------------------------------------------------------
def generar_logs():
    # Tráfico por hora: pico al almuerzo y pico fuerte en la noche (20h)
    peso_hora = [1.0, 0.6, 0.4, 0.3, 0.3, 0.5, 1.2, 2.5, 4.0, 5.0, 5.5, 6.0,
                 8.0, 7.5, 5.5, 5.0, 5.5, 6.0, 7.0, 9.0, 9.5, 7.0, 4.0, 2.0]
    paginas = ["/", "/productos", "/carrito", "/buscar?q=cafe", "/login",
               "/static/css/main.css", "/static/js/app.js",
               "/static/img/logo.png", "/api/v1/productos", "/checkout",
               "/buscar?q=salsa", "/api/v1/carrito", "/ofertas",
               "/blog/hadoop-para-principiantes", "/ayuda", "/contacto",
               "/logout", "/registro", "/buscar?q=pandebono", "/nosotros"]
    paginas += ["/producto/%d" % i for i in range(1, 301)]
    peso_pag = elegir_zipf(paginas, 1.1)
    ips = ["%d.%d.%d.%d" % (random.choice([181, 186, 190, 191, 200]),
                            random.randint(0, 255), random.randint(0, 255),
                            random.randint(1, 254)) for _ in range(2500)]
    meses = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep",
             "Oct", "Nov", "Dec"]
    inicio = datetime.datetime(2026, 11, 2)

    eventos = []
    horas = elegir(list(range(24)), peso_hora, k=300000)
    urls = elegir(paginas, peso_pag, k=300000)
    for i in range(300000):
        h = horas[i]
        t = inicio + datetime.timedelta(days=random.randint(0, 6), hours=h,
                                        minutes=random.randint(0, 59),
                                        seconds=random.randint(0, 59))
        url = urls[i]
        metodo = "POST" if url in ("/login", "/checkout", "/api/v1/carrito",
                                   "/registro") and random.random() < 0.6 else "GET"
        # En la hora pico de la noche el servidor se satura: más errores 5xx
        sobrecarga = h in (19, 20, 21)
        p500, p503 = (0.06, 0.04) if sobrecarga else (0.025, 0.01)
        r = random.random()
        if r < p500:
            status = 500
        elif r < p500 + p503:
            status = 503
        elif r < p500 + p503 + 0.05:
            status = 404
        elif r < p500 + p503 + 0.10:
            status = 304
        else:
            status = 200
        tam = "-" if status == 304 else str(random.randint(200, 48000))
        linea = '%s - - [%02d/%s/%d:%02d:%02d:%02d -0500] "%s %s HTTP/1.1" %d %s' % (
            random.choice(ips), t.day, meses[t.month - 1], t.year, t.hour,
            t.minute, t.second, metodo, url, status, tam)
        eventos.append((t, linea))
    eventos.sort(key=lambda e: e[0])
    lineas = [e[1] for e in eventos]

    # Algunas líneas dañadas, como en la vida real (el mapper debe ignorarlas)
    basura = ["ERROR conexión reiniciada por el cliente",
              "190.85.12.7 - - [05/Nov/2026:",
              "-- línea truncada --",
              "",
              "GET /producto/12 HTTP/1.1 200",
              "######## rotación de log ########"]
    for _ in range(42):
        lineas.insert(random.randint(0, len(lineas)), random.choice(basura))
    guardar("logs/access.log", lineas)


# ----------------------------------------------------------------------
# 3) Ventas (CSV)  fecha,ciudad,categoria,producto,cantidad,precio_unitario
#    Precios en pesos colombianos (enteros)
# ----------------------------------------------------------------------
def generar_ventas():
    ciudades = ["Bogotá", "Medellín", "Cali", "Barranquilla", "Cartagena",
                "Bucaramanga", "Pereira", "Manizales"]
    peso_ciudad = [30, 18, 16, 10, 8, 7, 6, 5]
    factor_ciudad = {"Bogotá": 1.10, "Medellín": 1.05, "Cali": 1.00,
                     "Barranquilla": 0.97, "Cartagena": 1.08,
                     "Bucaramanga": 0.95, "Pereira": 0.93, "Manizales": 0.92}
    catalogo = {
        "Tecnología": [("Portátil", 2800000), ("Celular", 1200000),
                       ("Audífonos", 180000), ("Mouse", 60000),
                       ("Monitor", 750000)],
        "Hogar": [("Licuadora", 220000), ("Cafetera", 160000),
                  ("Olla arrocera", 140000), ("Ventilador", 190000)],
        "Alimentos": [("Café 500g", 28000), ("Arroz 5kg", 22000),
                      ("Panela", 4500), ("Chocolate", 9000)],
        "Deportes": [("Balón", 95000), ("Bicicleta", 1400000),
                     ("Tenis", 320000), ("Guayos", 260000)],
        "Libros": [("Novela", 55000), ("Cómic", 35000),
                   ("Libro de Big Data", 120000)],
    }
    categorias = list(catalogo.keys())
    peso_cat = [15, 20, 35, 15, 15]
    lineas = ["fecha,ciudad,categoria,producto,cantidad,precio_unitario"]
    inicio = datetime.date(2026, 1, 1)
    for _ in range(120000):
        fecha = inicio + datetime.timedelta(days=random.randint(0, 303))
        ciudad = elegir(ciudades, peso_ciudad)[0]
        cat = elegir(categorias, peso_cat)[0]
        prod, base = random.choice(catalogo[cat])
        precio = int(round(base * factor_ciudad[ciudad] *
                           random.uniform(0.9, 1.1) / 100.0)) * 100
        cantidad = elegir([1, 2, 3, 4, 5], [50, 25, 12, 8, 5])[0]
        lineas.append("%s,%s,%s,%s,%d,%d" % (fecha.isoformat(), ciudad, cat,
                                             prod, cantidad, precio))
    # Filas con errores (valores faltantes): el mapper debe descartarlas
    for _ in range(25):
        i = random.randint(1, len(lineas) - 1)
        campos = lineas[i].split(",")
        if random.random() < 0.5:
            campos[4] = "N/A"
        else:
            campos[5] = ""
        lineas[i] = ",".join(campos)
    guardar("ventas/ventas.csv", lineas)


if __name__ == "__main__":
    print("Generando datasets en", BASE)
    generar_textos()
    generar_logs()
    generar_ventas()
    print("Listo.")
