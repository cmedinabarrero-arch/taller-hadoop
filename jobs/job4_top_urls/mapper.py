# -*- coding: utf-8 -*-
"""
JOB 4 - Top 10 URLs más visitadas  (MAPPER)

Entrada : líneas de access.log
Salida  : url <TAB> 1
"""
import io
import re
import sys

PATRON = re.compile(
    r'^(\S+) \S+ \S+ \[(\d{2})/(\w{3})/(\d{4}):(\d{2}):\d{2}:\d{2} [^\]]*\] '
    r'"(\S+) (\S+) [^"]*" (\d{3}) \S+$')


def main():
    entrada = io.TextIOWrapper(sys.stdin.buffer, encoding="utf-8", errors="replace")
    salida = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    for linea in entrada:
        m = PATRON.match(linea.rstrip("\r\n"))
        if not m:
            sys.stderr.write("reporter:counter:Taller,LineasMalformadas,1\n")
            continue
        salida.write("%s\t1\n" % m.group(7))
    salida.flush()


if __name__ == "__main__":
    main()
