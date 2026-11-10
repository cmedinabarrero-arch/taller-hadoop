# -*- coding: utf-8 -*-
"""
JOB 4 - Top 10 URLs  (REDUCER)

Se ejecuta con UN SOLO reducer (-D mapreduce.job.reduces=1) para que vea
TODAS las URLs y pueda decidir cuáles son las 10 primeras.

Entrada : url <TAB> cantidad   (ordenado por url; puede repetirse una url
          si varios combiners la enviaron)
Salida  : url <TAB> total      (solo las N más visitadas, de mayor a menor;
          en caso de empate, orden alfabético)

Variable opcional TOP_N (por defecto 10).
"""
import io
import os
import sys


def main():
    entrada = io.TextIOWrapper(sys.stdin.buffer, encoding="utf-8", errors="replace")
    salida = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    top_n = int(os.environ.get("TOP_N", "10"))

    # Guardamos solo una lista corta de candidatos (no todas las URLs):
    # cada cierto tiempo la ordenamos y recortamos. Así la memoria no crece
    # aunque haya millones de URLs distintas.
    candidatos = []

    def agregar(url, total):
        candidatos.append((-total, url))
        if len(candidatos) > top_n * 50:
            candidatos.sort()
            del candidatos[top_n:]

    actual, suma = None, 0
    for linea in entrada:
        partes = linea.rstrip("\r\n").split("\t")
        if len(partes) != 2:
            continue
        url, cantidad = partes[0], int(partes[1])
        if url != actual:
            if actual is not None:
                agregar(actual, suma)
            actual, suma = url, 0
        suma += cantidad
    if actual is not None:
        agregar(actual, suma)

    candidatos.sort()
    for menos_total, url in candidatos[:top_n]:
        salida.write("%s\t%d\n" % (url, -menos_total))
    salida.flush()


if __name__ == "__main__":
    main()
