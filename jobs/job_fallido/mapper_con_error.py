# -*- coding: utf-8 -*-
"""
JOB FALLIDO (a propósito) - para ver el estado FAILED y leer logs de error.

Lee unas líneas y luego divide entre cero -> Python lanza una excepción,
el proceso termina con error, Hadoop reintenta la tarea (hasta 4 intentos)
y como siempre falla, el job termina en estado FAILED.

En los logs (yarn logs -applicationId ...) verás el "Traceback" de Python
y el mensaje "ZeroDivisionError".
"""
import sys

for n, linea in enumerate(sys.stdin.buffer, 1):
    if n == 500:
        sys.stderr.write("A punto de fallar en la línea %d...\n" % n)
        resultado = 1 / 0
    sys.stdout.buffer.write(b"linea\t1\n")
