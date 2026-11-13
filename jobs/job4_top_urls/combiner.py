# -*- coding: utf-8 -*-
"""
JOB 4 - Top 10 URLs  (COMBINER)

Suma localmente, en el nodo del Map, los conteos de cada URL antes del
shuffle. Reduce la cantidad de registros que viajan por la red.

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
