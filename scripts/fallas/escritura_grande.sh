#!/usr/bin/env bash
# Sube un archivo grande a HDFS (por defecto 400 MB = 50 bloques de 8 MB).
# Mientras sube, reinicia un DataNode desde otra terminal para ver cómo
# HDFS recupera la "tubería" de escritura (pipeline recovery).
#   docker exec namenode bash /workspace/scripts/fallas/escritura_grande.sh [MB]
source /workspace/scripts/comun.sh
MB=${1:-400}

titulo "Creando archivo de $MB MB en /tmp del namenode"
dd if=/dev/urandom of=/tmp/grande.bin bs=1M count=$MB status=none
ls -lh /tmp/grande.bin

titulo "Subiendo a HDFS... (AHORA reinicia un DataNode en la otra terminal)"
hdfs dfs -mkdir -p /taller/pruebas
time hdfs dfs -put -f /tmp/grande.bin /taller/pruebas/grande.bin

titulo "Resultado"
hdfs dfs -ls -h /taller/pruebas/grande.bin
hdfs fsck /taller/pruebas/grande.bin 2>/dev/null \
  | grep -E 'Total blocks|Under-replicated|Missing|Corrupt|Status'
echo
echo "Comprobando que el contenido llegó íntegro (checksum local vs HDFS):"
echo "  local: $(md5sum < /tmp/grande.bin | cut -d' ' -f1)"
echo "  HDFS : $(hdfs dfs -cat /taller/pruebas/grande.bin | md5sum | cut -d' ' -f1)"
rm -f /tmp/grande.bin
echo
echo "Para borrarlo de HDFS:  hdfs dfs -rm -skipTrash /taller/pruebas/grande.bin"
