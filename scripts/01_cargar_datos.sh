#!/usr/bin/env bash
# Crea la estructura de carpetas en HDFS y sube los datasets.
#   docker exec namenode bash /workspace/scripts/01_cargar_datos.sh
#
# Estructura en HDFS:
#   /taller/entrada/textos/   <- texto_01.txt, texto_02.txt, texto_03.txt
#   /taller/entrada/logs/     <- access.log
#   /taller/entrada/ventas/   <- ventas.csv
#   /taller/salida/           <- aquí escriben los jobs (una carpeta por job)
set -e
source /workspace/scripts/comun.sh

titulo "Creando carpetas en HDFS"
hdfs dfs -mkdir -p /taller/entrada/textos /taller/entrada/logs \
                   /taller/entrada/ventas /taller/salida

titulo "Subiendo archivos (put)"
hdfs dfs -put -f /workspace/datos/textos/*.txt  /taller/entrada/textos/
hdfs dfs -put -f /workspace/datos/logs/access.log /taller/entrada/logs/
hdfs dfs -put -f /workspace/datos/ventas/ventas.csv /taller/entrada/ventas/

titulo "Contenido de /taller (hdfs dfs -ls -R)"
hdfs dfs -ls -R /taller/entrada

titulo "Espacio usado (hdfs dfs -du -h)"
hdfs dfs -du -h /taller/entrada

titulo "Bloques y réplicas de access.log (hdfs fsck)"
# Con bloques de 8 MB, el archivo de ~24 MB queda en 3 bloques,
# y cada bloque tiene 2 réplicas (una en cada DataNode).
hdfs fsck /taller/entrada/logs/access.log -files -blocks -locations 2>/dev/null \
  | grep -E 'access.log|blk_|Status'
