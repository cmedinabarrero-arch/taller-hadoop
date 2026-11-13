# -*- coding: utf-8 -*-
"""
JOB FALLIDO (a propósito) - para observar el estado FAILED y los logs de error.

Después de 500 líneas divide entre cero. La tarea falla siempre, YARN la
reintenta hasta 4 veces (mapreduce.map.maxattempts) y el job queda FAILED.
En los logs aparece el Traceback de Python con ZeroDivisionError.
"""
import sys

for n, linea in enumerate(sys.stdin.buffer, 1):
    if n == 500:
        sys.stderr.write("A punto de fallar en la línea %d...\n" % n)
        resultado = 1 / 0
    sys.stdout.buffer.write(b"linea\t1\n")
