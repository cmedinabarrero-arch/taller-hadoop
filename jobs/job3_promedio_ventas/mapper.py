# -*- coding: utf-8 -*-
"""
JOB 3 - Promedio de ventas por ciudad  (MAPPER)

Entrada : ventas.csv ->  fecha,ciudad,categoria,producto,cantidad,precio_unitario
Salida  : ciudad <TAB> monto        (monto = cantidad * precio_unitario, en COP)

Se descartan el encabezado y las filas con datos faltantes o inválidos
(se cuentan con contadores de Hadoop para verlos al final del job).
"""
import io
import sys


def contador(nombre):
    sys.stderr.write("reporter:counter:Taller,%s,1\n" % nombre)


def main():
    entrada = io.TextIOWrapper(sys.stdin.buffer, encoding="utf-8", errors="replace")
    salida = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

    for linea in entrada:
        linea = linea.rstrip("\r\n")
        if not linea:
            continue
        if linea.startswith("fecha,"):
            contador("Encabezados")
            continue
        campos = linea.split(",")
        if len(campos) != 6 or not campos[4].isdigit() or not campos[5].isdigit():
            contador("FilasInvalidas")
            continue
        monto = int(campos[4]) * int(campos[5])
        salida.write("%s\t%d\n" % (campos[1], monto))
        contador("FilasValidas")
    salida.flush()


if __name__ == "__main__":
    main()
