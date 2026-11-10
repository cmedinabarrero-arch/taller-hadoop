# -*- coding: utf-8 -*-
"""
JOB 2 - Horas pico en logs web  (REDUCER)

Entrada : líneas  hora <TAB> 1 <TAB> es_error   YA ORDENADAS por hora
Salida  : hora <TAB> peticiones <TAB> errores_5xx <TAB> %_error

Como la entrada llega ordenada, basta con ir sumando mientras la hora
no cambie; cuando cambia, se imprime el total de la hora anterior.
"""
import io
import sys


def main():
    entrada = io.TextIOWrapper(sys.stdin.buffer, encoding="utf-8", errors="replace")
    salida = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

    def emitir(hora, total, errores):
        salida.write("%s\t%d\t%d\t%.2f%%\n" % (hora, total, errores,
                                               100.0 * errores / total))

    actual, total, errores = None, 0, 0
    for linea in entrada:
        partes = linea.rstrip("\r\n").split("\t")
        if len(partes) != 3:
            continue
        hora, uno, err = partes
        if hora != actual:
            if actual is not None:
                emitir(actual, total, errores)
            actual, total, errores = hora, 0, 0
        total += int(uno)
        errores += int(err)
    if actual is not None:
        emitir(actual, total, errores)
    salida.flush()


if __name__ == "__main__":
    main()
