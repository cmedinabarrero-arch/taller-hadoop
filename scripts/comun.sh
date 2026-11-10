#!/usr/bin/env bash
# Funciones y variables compartidas por los demás scripts.
# (Se ejecutan DENTRO del contenedor namenode.)

STREAMING_JAR=$(ls "$HADOOP_HOME"/share/hadoop/tools/lib/hadoop-streaming-*.jar | head -1)
EXAMPLES_JAR=$(ls "$HADOOP_HOME"/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar | head -1)
JOBS=/workspace/jobs
EVIDENCIAS=/workspace/evidencias
mkdir -p "$EVIDENCIAS"

titulo() {
  echo
  echo "=================================================================="
  echo " $*"
  echo "=================================================================="
}

# correr_job <nombre> <comando...>
# Ejecuta el comando, guarda TODA la salida de consola en evidencias/,
# y al final muestra el ID de la aplicación YARN y su estado final.
correr_job() {
  local nombre=$1; shift
  local consola="$EVIDENCIAS/${nombre}_consola.txt"
  local inicio=$(date +%s)
  "$@" 2>&1 | tee "$consola"
  local estado=${PIPESTATUS[0]}
  local app=$(grep -o 'application_[0-9]*_[0-9]*' "$consola" | head -1)
  titulo "Resumen de $nombre"
  echo "Duración total : $(( $(date +%s) - inicio )) s"
  if [ -n "$app" ]; then
    echo "$app" > "$EVIDENCIAS/${nombre}_app_id.txt"
    echo "Aplicación YARN: $app"
    yarn application -status "$app" 2>/dev/null \
      | grep -E 'Application-Name|[^-]State :|Final-State|Progress' | sed 's/^\s*/  /'
    echo
    echo "Para ver los logs:  bash /workspace/scripts/ver_logs_job.sh $app"
  fi
  echo "Consola guardada en: evidencias/${nombre}_consola.txt"
  return $estado
}
