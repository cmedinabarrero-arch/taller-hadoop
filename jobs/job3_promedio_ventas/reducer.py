# -*- coding: utf-8 -*-
"""
JOB 3 - Promedio de ventas por ciudad  (REDUCER)

Entrada : ciudad <TAB> monto     (ordenado por ciudad)
Salida  : ciudad <TAB> num_ventas <TAB> total <TAB> promedio <TAB> minimo <TAB> maximo
"""
import io
import sys


def main():
    entrada = io.TextIOWrapper(sys.stdin.buffer, encoding="utf-8", errors="replace")
    salida = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

    def emitir(ciudad, n, total, minimo, maximo):
        salida.write("%s\t%d\t%d\t%.2f\t%d\t%d\n" % (
            ciudad, n, total, total / float(n), minimo, maximo))

    actual = None
    n = total = minimo = maximo = 0
    for linea in entrada:
        partes = linea.rstrip("\r\n").split("\t")
        if len(partes) != 2:
            continue
        ciudad, monto = partes[0], int(partes[1])
        if ciudad != actual:
            if actual is not None:
                emitir(actual, n, total, minimo, maximo)
            actual, n, total, minimo, maximo = ciudad, 0, 0, monto, monto
        n += 1
        total += monto
        minimo = min(minimo, monto)
        maximo = max(maximo, monto)
    if actual is not None:
        emitir(actual, n, total, minimo, maximo)
    salida.flush()


if __name__ == "__main__":
    main()
