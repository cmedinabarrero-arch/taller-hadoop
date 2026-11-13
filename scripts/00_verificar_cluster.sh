#!/usr/bin/env bash
# Verifica que HDFS y YARN estén funcionando.
#   docker exec namenode bash /workspace/scripts/00_verificar_cluster.sh
source /workspace/scripts/comun.sh

titulo "1. Versión de Hadoop"
hadoop version | head -1

titulo "2. Modo seguro del NameNode (debe decir OFF)"
hdfs dfsadmin -safemode get

titulo "3. DataNodes registrados en el NameNode"
hdfs dfsadmin -report 2>/dev/null \
  | grep -E '^Live datanodes|^Dead datanodes|^Name:|^Hostname:|^DFS Remaining%|^Last contact'

titulo "4. NodeManagers registrados en el ResourceManager"
yarn node -list -all 2>/dev/null

titulo "5. Prueba rápida de escritura/lectura en HDFS"
echo "hola HDFS desde el taller $(date)" > /tmp/prueba.txt
hdfs dfs -mkdir -p /taller/pruebas
hdfs dfs -put -f /tmp/prueba.txt /taller/pruebas/prueba.txt
hdfs dfs -cat /taller/pruebas/prueba.txt

titulo "Interfaces web"
echo "  HDFS NameNode        -> http://localhost:9870"
echo "  YARN ResourceManager -> http://localhost:8088"
echo "  JobHistory Server    -> http://localhost:19888"
echo "  NodeManager 1 / 2    -> http://localhost:8042  /  http://localhost:8043"
echo "  DataNode 1 / 2       -> http://localhost:9864  /  http://localhost:9865"
