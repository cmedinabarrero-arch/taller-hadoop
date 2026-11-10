# -*- coding: utf-8 -*-
"""
JOB 4 - Top 10 URLs  (COMBINER)

Un combiner es un "mini-reducer" que corre en el mismo nodo del Map, ANTES
de enviar los datos por la red. Aquí suma los 1 de cada URL localmente:
en vez de mandar 50.000 líneas "/producto/1  1", manda una sola
"/producto/1  50000". Menos tráfico en el shuffle = job más rápido.

Entrada y salida tienen el mismo formato:  url <TAB> cantidad
"""
import io
import sys


def main():
    entrada = io.TextIOWrapper(sys.stdin.buffer, encoding="utf-8", errors="replace")
    salida = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    actual, suma = None, 0
    for linea in entrada:
        partes = linea.rstrip("\r\n").split("\t")
        if len(partes) != 2:
            continue
        url, cantidad = partes[0], int(partes[1])
        if url != actual:
            if actual is not None:
                salida.write("%s\t%d\n" % (actual, suma))
            actual, suma = url, 0
        suma += cantidad
    if actual is not None:
        salida.write("%s\t%d\n" % (actual, suma))
    salida.flush()


if __name__ == "__main__":
    main()
