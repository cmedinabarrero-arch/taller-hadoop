# -*- coding: utf-8 -*-
"""
JOB 2 - Horas pico en logs web  (MAPPER)

Entrada : cada línea del archivo access.log, por ejemplo
          190.85.1.2 - - [02/Nov/2026:20:15:03 -0500] "GET /carrito HTTP/1.1" 500 1234
Salida  : hora <TAB> 1 <TAB> es_error
          (es_error = 1 si el código HTTP es 5xx, si no 0)

Hadoop ordena y agrupa por la clave (lo que va antes del primer TAB = la hora)
y le entrega al reducer todas las líneas de la misma hora juntas.

Variable opcional PAUSA (segundos): duerme PAUSA s cada 1000 líneas. Sirve
para que el job tarde más y poder provocar fallos mientras corre.
"""
import io
import os
import re
import sys
import time

PATRON = re.compile(
    r'^(\S+) \S+ \S+ \[(\d{2})/(\w{3})/(\d{4}):(\d{2}):\d{2}:\d{2} [^\]]*\] '
    r'"(\S+) (\S+) [^"]*" (\d{3}) \S+$')


def contador(nombre):
    # Hadoop Streaming entiende esta línea en stderr como un "contador"
    sys.stderr.write("reporter:counter:Taller,%s,1\n" % nombre)


def main():
    entrada = io.TextIOWrapper(sys.stdin.buffer, encoding="utf-8", errors="replace")
    salida = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    pausa = float(os.environ.get("PAUSA", "0") or 0)

    for n, linea in enumerate(entrada, 1):
        if pausa > 0 and n % 1000 == 0:
            time.sleep(pausa)
            sys.stderr.write("reporter:status:procesadas %d lineas\n" % n)
        m = PATRON.match(linea.rstrip("\r\n"))
        if not m:
            contador("LineasMalformadas")
            continue
        hora = m.group(5)
        es_error = 1 if int(m.group(8)) >= 500 else 0
        salida.write("%s\t1\t%d\n" % (hora, es_error))
    salida.flush()


if __name__ == "__main__":
    main()
