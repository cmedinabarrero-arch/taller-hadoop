#!/usr/bin/env bash
# Hace FALLAR a propósito una tarea Map que esté corriendo (simula que el
# proceso Map se cae a mitad de trabajo) y muestra cómo YARN la reintenta.
#
#   docker exec namenode bash /workspace/scripts/fallas/fallar_tarea.sh
#       -> falla UN intento: YARN lanza el intento _1 y el job termina bien (SUCCEEDED)
#   docker exec namenode bash /workspace/scripts/fallas/fallar_tarea.sh --hasta-fallar
#       -> falla la MISMA tarea 4 veces: se agotan los reintentos y el job queda FAILED
#
# Requiere un job lento corriendo en otra terminal:
#   docker exec namenode bash /workspace/scripts/job2_horas_pico.sh 1
source /workspace/scripts/comun.sh
MODO=$1

JOB=$(mapred job -list 2>/dev/null | grep -oE 'job_[0-9]+_[0-9]+' | head -1)
if [ -z "$JOB" ]; then
  echo "No hay jobs corriendo. Lanza primero:  bash /workspace/scripts/job2_horas_pico.sh 1"
  exit 1
fi
echo "Job en ejecución: $JOB"

esperar_intento() {  # espera a que aparezca un intento Map corriendo (de la tarea $1 si se da)
  for _ in $(seq 1 40); do
    ATT=$(mapred job -list-attempt-ids "$JOB" MAP running 2>/dev/null | grep "${1:-attempt_}" | head -1)
    [ -n "$ATT" ] && return 0
    sleep 3
  done
  return 1
}

esperar_intento || { echo "No encontré tareas Map corriendo."; exit 1; }
TAREA=$(echo "$ATT" | sed -E 's/^attempt_(.*)_[0-9]+$/\1/')   # ej: 1731_0001_m_000000

if [ "$MODO" != "--hasta-fallar" ]; then
  echo "Haciendo fallar el intento: $ATT"
  mapred job -fail-task "$ATT"
  echo
  echo "Listo. En unos segundos YARN lanzará el intento siguiente (_1) de la misma tarea."
  echo "Míralo en la consola del job (Status : FAILED) o en http://localhost:8088"
  exit 0
fi

for i in 1 2 3 4; do
  esperar_intento "$TAREA" || break
  echo "[$i/4] Haciendo fallar $ATT"
  mapred job -fail-task "$ATT" >/dev/null 2>&1
  sleep 5
done
sleep 5
echo
mapred job -status "$JOB" 2>/dev/null | grep -E 'Job state|failure info|Job File'
echo "Con 4 intentos fallidos (mapreduce.map.maxattempts=4) el job completo queda FAILED."
