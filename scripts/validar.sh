#!/usr/bin/env bash
# VALIDACIÓN MANUAL de los resultados.
# Recalcula cada resultado con herramientas clásicas de Linux (awk, sort)
# directamente sobre los archivos ORIGINALES (sin Hadoop) y los compara
# con lo que MapReduce dejó en HDFS. Si coinciden -> el job es correcto.
#   docker exec namenode bash /workspace/scripts/validar.sh
source /workspace/scripts/comun.sh
export LC_ALL=C
DATOS=/workspace/datos
TMP=$(mktemp -d)
FALLOS=0

# Misma regla que el mapper para decidir si una línea de log es válida
LOG_VALIDA='NF==10 && $4 ~ /^\[[0-9][0-9]\/[A-Za-z][A-Za-z][A-Za-z]\/[0-9][0-9][0-9][0-9]:[0-9][0-9]:/ && $9 ~ /^[0-9][0-9][0-9]$/'

comparar() {  # comparar <nombre> <esperado> <obtenido>
  if [ ! -s "$3" ]; then
    echo "[--] $1: no hay salida en HDFS (¿ya corriste el job?)"
  elif diff -q "$2" "$3" >/dev/null; then
    echo "[OK] $1: los $(wc -l < "$2") registros coinciden exactamente"
  else
    echo "[X]  $1: HAY DIFERENCIAS (esperado < > obtenido):"
    diff "$2" "$3" | head -10
    FALLOS=$((FALLOS+1))
  fi
}

titulo "Validación manual: awk/sort sobre los archivos originales vs HDFS"

# JOB 1: contar palabras con awk
cat $DATOS/textos/*.txt \
  | awk '{for(i=1;i<=NF;i++) c[$i]++} END{for(w in c) printf "%s\t%d\n", w, c[w]}' \
  | sort > $TMP/j1_esp
hdfs dfs -cat /taller/salida/job1_wordcount/part-* 2>/dev/null | sort > $TMP/j1_obt
comparar "Job 1 WordCount" $TMP/j1_esp $TMP/j1_obt

# JOB 2: peticiones y errores 5xx por hora
awk "$LOG_VALIDA"' { split($4, t, ":"); h=t[2]; n[h]++; if ($9+0 >= 500) e[h]++ }
     END { for (h in n) printf "%s\t%d\t%d\n", h, n[h], e[h]+0 }' $DATOS/logs/access.log \
  | sort > $TMP/j2_esp
hdfs dfs -cat /taller/salida/job2_horas_pico/part-* 2>/dev/null | cut -f1-3 | sort > $TMP/j2_obt
comparar "Job 2 Horas pico" $TMP/j2_esp $TMP/j2_obt

# JOB 3: número de ventas, total y promedio por ciudad
awk -F, '$1!="fecha" && NF==6 && $5 ~ /^[0-9]+$/ && $6 ~ /^[0-9]+$/ {
           m=$5*$6; n[$2]++; s[$2]+=m }
         END { for (c in n) printf "%s\t%d\t%.0f\t%.2f\n", c, n[c], s[c], s[c]/n[c] }' \
  $DATOS/ventas/ventas.csv | sort > $TMP/j3_esp
hdfs dfs -cat /taller/salida/job3_promedio_ciudad/part-* 2>/dev/null | cut -f1-4 | sort > $TMP/j3_obt
comparar "Job 3 Promedio por ciudad" $TMP/j3_esp $TMP/j3_obt

# JOB 4: top 10 URLs (desempate alfabético, igual que el reducer)
awk "$LOG_VALIDA"' { c[$7]++ } END { for (u in c) printf "%s\t%d\n", u, c[u] }' \
  $DATOS/logs/access.log | sort -t"$(printf '\t')" -k2,2nr -k1,1 | head -10 > $TMP/j4_esp
hdfs dfs -cat /taller/salida/job4_top_urls/part-* 2>/dev/null > $TMP/j4_obt
comparar "Job 4 Top 10 URLs" $TMP/j4_esp $TMP/j4_obt

echo
echo "Líneas de log descartadas por mal formato: $(awk "!($LOG_VALIDA)" $DATOS/logs/access.log | wc -l)"
echo "Filas de ventas inválidas:                 $(awk -F, '$1!="fecha" && !(NF==6 && $5 ~ /^[0-9]+$/ && $6 ~ /^[0-9]+$/)' $DATOS/ventas/ventas.csv | wc -l)"
echo "(Compáralas con los contadores 'Taller' que imprimió cada job.)"
rm -rf $TMP
exit $FALLOS
