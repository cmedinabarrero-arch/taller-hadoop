#!/usr/bin/env bash
# Muestra la salud de HDFS: DataNodes vivos/muertos, bloques sub-replicados,
# y dónde está cada réplica de access.log.
#   docker exec namenode bash /workspace/scripts/fallas/estado_hdfs.sh
#   docker exec -it namenode bash /workspace/scripts/fallas/estado_hdfs.sh --seguir   (se repite cada 5 s; Ctrl+C para salir)
source /workspace/scripts/comun.sh

mostrar() {
  titulo "DataNodes  ($(date +%H:%M:%S))"
  hdfs dfsadmin -report 2>/dev/null \
    | grep -E '^Live datanodes|^Dead datanodes|^Hostname:|^Last contact|^Under replicated|^Missing blocks'
  titulo "Salud del sistema de archivos (hdfs fsck /)"
  hdfs fsck / 2>/dev/null \
    | grep -E 'Total blocks|Minimally replicated|Under-replicated|Missing blocks|Corrupt blocks|Average block replication|Number of data-nodes|Status:'
  titulo "Réplicas de cada bloque de access.log"
  hdfs fsck /taller/entrada/logs/access.log -files -blocks -locations 2>/dev/null \
    | grep -E 'blk_' | sed -E 's/.*(blk_[0-9]+)_[0-9]+ len=([0-9]+) Live_repl=([0-9]+).*/  \1  réplicas vivas=\3/'
  hdfs fsck /taller/entrada/logs/access.log -files -blocks -locations 2>/dev/null \
    | grep -oE 'DatanodeInfoWithStorage\[[0-9.:]+' | sed 's/DatanodeInfoWithStorage\[/  en /' | sort | uniq -c
}

if [ "$1" == "--seguir" ]; then
  while true; do clear; mostrar; sleep 5; done
else
  mostrar
fi
