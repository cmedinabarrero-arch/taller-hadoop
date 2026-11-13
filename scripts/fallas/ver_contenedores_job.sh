#!/usr/bin/env bash
# Muestra EN QUÉ NODEMANAGER está corriendo cada contenedor de un job.
# Útil con un job lento en ejecución, para decidir qué NodeManager apagar.
#   docker exec namenode bash /workspace/scripts/fallas/ver_contenedores_job.sh            (toma el job que esté corriendo)
#   docker exec namenode bash /workspace/scripts/fallas/ver_contenedores_job.sh application_XXX
source /workspace/scripts/comun.sh
APP=${1:-$(yarn application -list -appStates RUNNING 2>/dev/null | grep -o 'application_[0-9]*_[0-9]*' | head -1)}
if [ -z "$APP" ]; then
  echo "No hay ningún job corriendo. Lanza uno lento primero, por ejemplo:"
  echo "  docker exec namenode bash /workspace/scripts/job2_horas_pico.sh 1"
  exit 1
fi

titulo "Intentos del ApplicationMaster de $APP"
yarn applicationattempt -list "$APP" 2>/dev/null

for ATT in $(yarn applicationattempt -list "$APP" 2>/dev/null | grep -o 'appattempt_[0-9_]*'); do
  titulo "Contenedores del intento $ATT"
  printf "  %-45s %-10s %s\n" "CONTENEDOR" "ESTADO" "NODO"
  yarn container -list "$ATT" 2>/dev/null | grep 'container_' | while read -r l; do
    id=$(echo "$l" | grep -oE 'container_[0-9_e]+' | head -1)
    st=$(echo "$l" | grep -oE 'RUNNING|COMPLETE|NEW|ALLOCATED|ACQUIRED' | head -1)
    host=$(echo "$l" | grep -oE 'nodemanager[0-9]+' | head -1)
    printf "  %-45s %-10s %s\n" "$id" "$st" "$host"
  done
done

titulo "Contenedores por NodeManager"
yarn node -list 2>/dev/null
echo
echo "El contenedor terminado en _000001 es el ApplicationMaster del job."
