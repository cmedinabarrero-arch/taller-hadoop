#!/usr/bin/env bash
# Descarga y resume los logs de un job (de todos sus contenedores).
#   docker exec namenode bash /workspace/scripts/ver_logs_job.sh application_XXXX_YYYY
# Sin parámetro: lista las aplicaciones para que copies el ID.
source /workspace/scripts/comun.sh
APP=$1

if [ -z "$APP" ]; then
  titulo "Aplicaciones en YARN (todas): copia el ID de la que quieras"
  yarn application -list -appStates ALL 2>/dev/null
  exit 0
fi

titulo "Estado de $APP"
yarn application -status "$APP" 2>/dev/null

titulo "Intentos del ApplicationMaster"
yarn applicationattempt -list "$APP" 2>/dev/null

ARCHIVO="$EVIDENCIAS/logs_${APP}.txt"
yarn logs -applicationId "$APP" > "$ARCHIVO" 2>/dev/null
if [ ! -s "$ARCHIVO" ]; then
  echo "Aún no hay logs agregados (el job sigue corriendo o acaba de terminar)."
  echo "Espera unos segundos y vuelve a intentar."
  exit 0
fi

titulo "Contenedores que participaron (y en qué nodo corrieron)"
grep -E '^Container: ' "$ARCHIVO" | sort -u

titulo "Errores encontrados en los logs (Traceback / Exception / ERROR)"
grep -nE 'Traceback|Error|Exception|FAILED' "$ARCHIVO" | head -25

echo
echo "Log completo guardado en: evidencias/logs_${APP}.txt  (ábrelo en VS Code)"
